use axum::{Router, routing::{get, post}};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing_subscriber;

mod routes;
mod models;
mod state;
mod db;
mod error;

use state::AppState;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&std::env::var("DATABASE_URL")?)
        .await?;

    sqlx::migrate!("./migrations").run(&db).await?;

    let state = Arc::new(AppState::new(db));

    let app = Router::new()
        // Auth
        .route("/auth/register", post(routes::auth::register))
        .route("/auth/login",    post(routes::auth::login))
        // Payments
        .route("/payments/request", post(routes::payments::request_payment))
        .route("/payments/accept",  post(routes::payments::accept_payment))
        .route("/payments/decline", post(routes::payments::decline_payment))
        // WebSocket
        .route("/ws", get(routes::ws::ws_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    tracing::info!("Listening on :8080");
    axum::serve(listener, app).await?;

    Ok(())
}
