use axum::{
    extract::{State, WebSocketUpgrade, ws::{WebSocket, Message}},
    response::Response,
};
use std::sync::Arc;
use tokio::sync::mpsc;
use uuid::Uuid;

use crate::{state::AppState, routes::auth::Claims, error::AppError};

// Client connects: GET /ws?token=<jwt>
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Response, AppError> {
    let token = params.get("token").ok_or(AppError::Unauthorized)?;
    let user_id = Claims::verify(token)?;

    Ok(ws.on_upgrade(move |socket| handle_socket(socket, state, user_id)))
}

async fn handle_socket(mut socket: WebSocket, state: Arc<AppState>, user_id: Uuid) {
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();
    state.connections.insert(user_id, tx);

    tracing::info!("WS connected: {}", user_id);

    loop {
        tokio::select! {
            // Forward server events to this client
            Some(msg) = rx.recv() => {
                if socket.send(Message::Text(msg)).await.is_err() {
                    break;
                }
            }
            // Handle or ignore incoming client messages
            result = socket.recv() => {
                match result {
                    Some(Ok(_)) => {} // ping/keepalive
                    _ => break,       // disconnect
                }
            }
        }
    }

    state.connections.remove(&user_id);
    tracing::info!("WS disconnected: {}", user_id);
}
