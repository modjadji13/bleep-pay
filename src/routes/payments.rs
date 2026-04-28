use axum::{extract::State, Json};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use std::sync::Arc;
use uuid::Uuid;

use crate::{
    error::AppError,
    routes::auth::AuthUser,
    state::{AppState, PendingPayment},
};

#[derive(Deserialize)]
pub struct PaymentRequest {
    pub to_user_id: Uuid,
    pub amount_cents: i64,
}

#[derive(Serialize)]
pub struct PaymentResponse {
    pub payment_id: Uuid,
    pub status: String,
}

#[derive(Serialize, FromRow)]
pub struct HistoryTransaction {
    pub id: Uuid,
    pub from_user: Option<Uuid>,
    pub to_user: Option<Uuid>,
    pub amount_cents: i64,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(FromRow)]
struct PendingTransactionRow {
    id: Uuid,
    from_user: Uuid,
    to_user: Uuid,
    amount_cents: i64,
}

// POST /payments/request
// Sender initiates: "I want to send $X to this person"
pub async fn request_payment(
    State(state): State<Arc<AppState>>,
    AuthUser(from_user): AuthUser,
    Json(body): Json<PaymentRequest>,
) -> Result<Json<PaymentResponse>, AppError> {
    if body.amount_cents <= 0 || body.amount_cents > 1_000_000 {
        return Err(AppError::BadRequest("Invalid amount".into()));
    }

    let payment_id = Uuid::new_v4();
    let pending = PendingPayment {
        id: payment_id,
        from_user,
        to_user: body.to_user_id,
        amount_cents: body.amount_cents,
    };

    sqlx::query(
        "INSERT INTO transactions (id, from_user, to_user, amount_cents, status)
         VALUES ($1, $2, $3, $4, 'pending')",
    )
    .bind(pending.id)
    .bind(pending.from_user)
    .bind(pending.to_user)
    .bind(pending.amount_cents)
    .execute(&state.db)
    .await?;

    state.pending.insert(payment_id, pending.clone());

    state.push_event(
        body.to_user_id,
        serde_json::json!({
            "event": "payment_request",
            "payment_id": payment_id,
            "from_user": from_user,
            "amount_cents": body.amount_cents,
        }),
    );

    Ok(Json(PaymentResponse {
        payment_id,
        status: "pending".into(),
    }))
}

// GET /transactions/history
pub async fn get_history(
    State(state): State<Arc<AppState>>,
    AuthUser(user_id): AuthUser,
) -> Result<Json<Vec<HistoryTransaction>>, AppError> {
    let rows = sqlx::query_as::<_, HistoryTransaction>(
        "SELECT id, from_user, to_user, amount_cents, status, created_at
         FROM transactions
         WHERE from_user = $1 OR to_user = $1
         ORDER BY created_at DESC
         LIMIT 50",
    )
    .bind(user_id)
    .fetch_all(&state.db)
    .await?;

    Ok(Json(rows))
}

// POST /payments/accept  { payment_id }
pub async fn accept_payment(
    State(state): State<Arc<AppState>>,
    AuthUser(user_id): AuthUser,
    Json(body): Json<serde_json::Value>,
) -> Result<Json<PaymentResponse>, AppError> {
    let payment_id: Uuid = body["payment_id"]
        .as_str()
        .and_then(|s| s.parse().ok())
        .ok_or(AppError::BadRequest("Missing payment_id".into()))?;

    let pending = load_pending_payment(&state, payment_id).await?;
    state.pending.remove(&payment_id);

    if pending.to_user != user_id {
        return Err(AppError::Unauthorized);
    }

    execute_transfer(&state, &pending).await?;

    sqlx::query("UPDATE transactions SET status = 'completed' WHERE id = $1")
        .bind(payment_id)
        .execute(&state.db)
        .await?;

    let event = serde_json::json!({
        "event": "payment_completed",
        "payment_id": payment_id,
        "amount_cents": pending.amount_cents,
    });
    state.push_event(pending.from_user, event.clone());
    state.push_event(pending.to_user, event);

    Ok(Json(PaymentResponse {
        payment_id,
        status: "completed".into(),
    }))
}

// POST /payments/decline  { payment_id }
pub async fn decline_payment(
    State(state): State<Arc<AppState>>,
    AuthUser(user_id): AuthUser,
    Json(body): Json<serde_json::Value>,
) -> Result<Json<PaymentResponse>, AppError> {
    let payment_id: Uuid = body["payment_id"]
        .as_str()
        .and_then(|s| s.parse().ok())
        .ok_or(AppError::BadRequest("Missing payment_id".into()))?;

    let pending = load_pending_payment(&state, payment_id).await?;
    state.pending.remove(&payment_id);

    if pending.to_user != user_id {
        return Err(AppError::Unauthorized);
    }

    sqlx::query("UPDATE transactions SET status = 'declined' WHERE id = $1")
        .bind(payment_id)
        .execute(&state.db)
        .await?;

    state.push_event(
        pending.from_user,
        serde_json::json!({
            "event": "payment_declined",
            "payment_id": payment_id,
        }),
    );

    Ok(Json(PaymentResponse {
        payment_id,
        status: "declined".into(),
    }))
}

async fn load_pending_payment(state: &AppState, payment_id: Uuid) -> Result<PendingPayment, AppError> {
    if let Some((_, pending)) = state.pending.remove(&payment_id) {
        return Ok(pending);
    }

    let row = sqlx::query_as::<_, PendingTransactionRow>(
        "SELECT id, from_user, to_user, amount_cents
         FROM transactions
         WHERE id = $1 AND status = 'pending'",
    )
    .bind(payment_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound("Payment not found or expired".into()))?;

    Ok(PendingPayment {
        id: row.id,
        from_user: row.from_user,
        to_user: row.to_user,
        amount_cents: row.amount_cents,
    })
}

async fn execute_transfer(_state: &AppState, payment: &PendingPayment) -> Result<(), AppError> {
    tracing::info!(
        "Transferring {} cents from {} to {}",
        payment.amount_cents, payment.from_user, payment.to_user
    );
    Ok(())
}
