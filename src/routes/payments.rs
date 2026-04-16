use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use uuid::Uuid;

use crate::{state::{AppState, PendingPayment}, error::AppError, routes::auth::AuthUser};

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

    state.pending.insert(payment_id, pending);

    // Push real-time event to the recipient
    state.push_event(body.to_user_id, serde_json::json!({
        "event": "payment_request",
        "payment_id": payment_id,
        "from_user": from_user,
        "amount_cents": body.amount_cents,
    }));

    Ok(Json(PaymentResponse {
        payment_id,
        status: "pending".into(),
    }))
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

    let (_, pending) = state.pending
        .remove(&payment_id)
        .ok_or(AppError::NotFound("Payment not found or expired".into()))?;

    // Must be the intended recipient
    if pending.to_user != user_id {
        return Err(AppError::Unauthorized);
    }

    // Execute the transfer via Stripe (or your payment processor)
    // For now: stub - replace with real Stripe call
    execute_transfer(&state, &pending).await?;

    // Record in DB
    sqlx::query(
        "INSERT INTO transactions (id, from_user, to_user, amount_cents, status)
         VALUES ($1, $2, $3, $4, 'completed')",
    )
    .bind(pending.id)
    .bind(pending.from_user)
    .bind(pending.to_user)
    .bind(pending.amount_cents)
    .execute(&state.db)
    .await?;

    // Notify both parties
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

    let (_, pending) = state.pending
        .remove(&payment_id)
        .ok_or(AppError::NotFound("Payment not found".into()))?;

    if pending.to_user != user_id {
        return Err(AppError::Unauthorized);
    }

    state.push_event(pending.from_user, serde_json::json!({
        "event": "payment_declined",
        "payment_id": payment_id,
    }));

    Ok(Json(PaymentResponse {
        payment_id,
        status: "declined".into(),
    }))
}

async fn execute_transfer(_state: &AppState, payment: &PendingPayment) -> Result<(), AppError> {
    // 1. Look up Stripe customer IDs for both users from DB
    // 2. Call Stripe Transfer API
    // For now: stub - replace with real Stripe call
    tracing::info!(
        "Transferring {} cents from {} to {}",
        payment.amount_cents, payment.from_user, payment.to_user
    );
    Ok(())
}
