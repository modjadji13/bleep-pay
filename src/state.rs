use dashmap::DashMap;
use sqlx::PgPool;
use tokio::sync::mpsc;
use uuid::Uuid;

// Each WS connection gets a sender to push events to the client
pub type WsSender = mpsc::UnboundedSender<String>;

pub struct AppState {
    pub db: PgPool,
    // user_id -> their WS channel
    pub connections: DashMap<Uuid, WsSender>,
    // payment_id -> pending payment (in-flight, not yet in DB)
    pub pending: DashMap<Uuid, PendingPayment>,
}

#[derive(Clone, Debug)]
pub struct PendingPayment {
    pub id: Uuid,
    pub from_user: Uuid,
    pub to_user: Uuid,
    pub amount_cents: i64, // always store money as cents
}

impl AppState {
    pub fn new(db: PgPool) -> Self {
        Self {
            db,
            connections: DashMap::new(),
            pending: DashMap::new(),
        }
    }

    pub fn push_event(&self, user_id: Uuid, event: serde_json::Value) {
        if let Some(tx) = self.connections.get(&user_id) {
            let _ = tx.send(event.to_string());
        }
    }
}
