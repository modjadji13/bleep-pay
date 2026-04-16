use axum::{
    async_trait,
    extract::{FromRequestParts, State},
    http::request::Parts,
    Json,
};
use bcrypt::{hash, verify, DEFAULT_COST};
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use uuid::Uuid;

use crate::{error::AppError, state::AppState};

// ?? JWT Claims ????????????????????????????????????????????????????????????????

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: Uuid,   // user id
    pub exp: i64,    // unix timestamp expiry
}

impl Claims {
    pub fn new(user_id: Uuid) -> Self {
        Self {
            sub: user_id,
            exp: (Utc::now() + Duration::days(30)).timestamp(),
        }
    }

    pub fn verify(token: &str) -> Result<Uuid, AppError> {
        let secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "dev_secret".into());
        let data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| AppError::Unauthorized)?;

        Ok(data.claims.sub)
    }

    pub fn sign(&self) -> Result<String, AppError> {
        let secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "dev_secret".into());
        encode(
            &Header::default(),
            self,
            &EncodingKey::from_secret(secret.as_bytes()),
        )
        .map_err(|e| AppError::Internal(anyhow::anyhow!(e)))
    }
}

// ?? AuthUser extractor ????????????????????????????????????????????????????????
// Use as a parameter in any handler: AuthUser(user_id): AuthUser

pub struct AuthUser(pub Uuid);

#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or(AppError::Unauthorized)?;

        let user_id = Claims::verify(token)?;
        Ok(AuthUser(user_id))
    }
}

// ?? Request / Response types ?????????????????????????????????????????????????-

#[derive(Deserialize)]
pub struct AuthRequest {
    pub phone: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user_id: Uuid,
}

// ?? Handlers ?????????????????????????????????????????????????????????????????-

// POST /auth/register
pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(body): Json<AuthRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    // Basic validation
    if body.phone.trim().is_empty() || body.password.len() < 6 {
        return Err(AppError::BadRequest(
            "Phone required and password must be at least 6 characters".into(),
        ));
    }

    // Check duplicate
    let existing: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE phone = $1")
        .bind(body.phone.trim())
        .fetch_optional(&state.db)
        .await?;

    if existing.is_some() {
        return Err(AppError::BadRequest("Phone number already registered".into()));
    }

    // Hash password
    let password_hash =
        hash(&body.password, DEFAULT_COST).map_err(|e| AppError::Internal(anyhow::anyhow!(e)))?;

    // Insert user
    let user_id: Uuid = sqlx::query_scalar(
        "INSERT INTO users (phone, password_hash) VALUES ($1, $2) RETURNING id",
    )
    .bind(body.phone.trim())
    .bind(password_hash)
    .fetch_one(&state.db)
    .await?;

    let token = Claims::new(user_id).sign()?;

    Ok(Json(AuthResponse { token, user_id }))
}

// POST /auth/login
pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(body): Json<AuthRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    // Fetch user
    let row: Option<(Uuid, String)> = sqlx::query_as(
        "SELECT id, password_hash FROM users WHERE phone = $1",
    )
    .bind(body.phone.trim())
    .fetch_optional(&state.db)
    .await?;

    let (user_id, password_hash) =
        row.ok_or_else(|| AppError::BadRequest("Invalid phone or password".into()))?;

    // Verify password ? use same error message to avoid user enumeration
    let valid = verify(&body.password, &password_hash)
        .map_err(|e| AppError::Internal(anyhow::anyhow!(e)))?;

    if !valid {
        return Err(AppError::BadRequest("Invalid phone or password".into()));
    }

    let token = Claims::new(user_id).sign()?;

    Ok(Json(AuthResponse {
        token,
        user_id,
    }))
}
