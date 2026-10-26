mod domain;
mod mysql_repo;
use argon2::{Argon2, PasswordHash, PasswordVerifier};
use axum::{
    extract::{Path, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{Html, IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use domain::{id, text};
use mysql_repo::{db_error, user_row, Repository};
use serde_json::{json, Value};
use sqlx::Row;
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
struct App {
    repo: Repository,
    attempts: Mutex<HashMap<String, (u32, Instant)>>,
}
type Shared = Arc<App>;
pub(crate) struct ApiError(StatusCode, String);
impl From<String> for ApiError {
    fn from(s: String) -> Self {
        Self(StatusCode::BAD_REQUEST, s)
    }
}
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.0, Json(json!({"error":self.1}))).into_response()
    }
}
pub(crate) type ApiResult = Result<Json<Value>, ApiError>;
fn token(headers: &HeaderMap) -> String {
    headers
        .get(header::COOKIE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .split(';')
        .find_map(|v| v.trim().strip_prefix("sga_session="))
        .unwrap_or("")
        .to_owned()
}
async fn security_headers(mut response: Response) -> Response {
    let h = response.headers_mut();
    h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    h.insert(
        "x-content-type-options",
        HeaderValue::from_static("nosniff"),
    );
    h.insert("x-frame-options", HeaderValue::from_static("DENY"));
    h.insert("referrer-policy", HeaderValue::from_static("same-origin"));
    h.insert("content-security-policy",HeaderValue::from_static("default-src 'self'; script-src 'self'; style-src 'self'; style-src-attr 'none'; img-src 'self' data:; object-src 'none'; base-uri 'none'; connect-src 'self'; media-src 'self'; frame-ancestors 'none'; form-action 'self'"));
    h.insert("permissions-policy", HeaderValue::from_static("camera=(), microphone=(), geolocation=()"));
    response
}
async fn login(State(state): State<Shared>, Json(body): Json<Value>) -> Result<Response, ApiError> {
    let login = text(&body, "login").trim().to_lowercase();
    let password = text(&body, "senha").to_owned();
    if login.is_empty() || login.len() > 100 || password.is_empty() || password.len() > 128 {
        return Err(ApiError(
            StatusCode::UNAUTHORIZED,
            "Login ou senha incorretos.".into(),
        ));
    }
    {
        let mut attempts = state.attempts.lock().unwrap();
        attempts.retain(|_, (_, t)| t.elapsed() < Duration::from_secs(60));
        if attempts.get(&login).is_some_and(|(n, _)| *n >= 8) {
            return Err(ApiError(
                StatusCode::TOO_MANY_REQUESTS,
                "Muitas tentativas. Aguarde um minuto.".into(),
            ));
        }
    }
    let mut conn = state.repo.acquire().await?;
    let cred = sqlx::query("CALL sp_CredencialLogin(?)")
        .bind(&login)
        .fetch_optional(&mut *conn)
        .await
        .map_err(db_error)?;
    let exists = cred.is_some();
    let hash = cred
        .map(|r| r.try_get_unchecked::<String, _>(0))
        .transpose()
        .map_err(db_error)?
        .unwrap_or_else(|| include_str!("../database/auth_dummy.txt").to_owned());
    let proof = hash.clone();
    let valid = tokio::task::spawn_blocking(move || {
        PasswordHash::new(&hash).is_ok_and(|h| {
            Argon2::default()
                .verify_password(password.as_bytes(), &h)
                .is_ok()
        })
    })
    .await
    .map_err(|_| {
        ApiError(
            StatusCode::INTERNAL_SERVER_ERROR,
            "Não foi possível validar as credenciais.".into(),
        )
    })?;
    if !valid || !exists {
        let mut a = state.attempts.lock().unwrap();
        a.entry(login).or_insert((0, Instant::now())).0 += 1;
        return Err(ApiError(
            StatusCode::UNAUTHORIZED,
            "Login ou senha incorretos.".into(),
        ));
    }
    let row = sqlx::query("CALL sp_LoginUsuario(?,?)")
        .bind(&login)
        .bind(proof)
        .fetch_one(&mut *conn)
        .await
        .map_err(db_error)?;
    state.attempts.lock().unwrap().remove(&login);
    let user = user_row(&row)?;
    let session = row.try_get_unchecked::<String, _>(4).map_err(db_error)?;
    let mut headers = HeaderMap::new();
    headers.insert(
        header::SET_COOKIE,
        format!("sga_session={session}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800")
            .parse()
            .unwrap(),
    );
    Ok((headers, Json(user)).into_response())
}
async fn logout(State(state): State<Shared>, headers: HeaderMap) -> Result<Response, ApiError> {
    if let Ok((mut conn, _)) = state.repo.authenticate_connection(&token(&headers)).await {
        sqlx::query("CALL sp_LogoutUsuario()")
            .execute(&mut *conn)
            .await
            .map_err(db_error)?;
    }
    Ok((
        [(
            header::SET_COOKIE,
            "sga_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0",
        )],
        Json(json!({"ok":true})),
    )
        .into_response())
}
async fn me(State(state): State<Shared>, headers: HeaderMap) -> ApiResult {
    let (_, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Ok(Json(user))
}
async fn data(State(state): State<Shared>, headers: HeaderMap) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Ok(Json(Repository::data(&mut conn, id(&user, "id")).await?))
}
async fn create(
    State(state): State<Shared>,
    headers: HeaderMap,
    Path(kind): Path<String>,
    Json(body): Json<Value>,
) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Repository::upsert(&mut conn, &user, &kind, None, body).await
}
async fn update(
    State(state): State<Shared>,
    headers: HeaderMap,
    Path((kind, key)): Path<(String, u64)>,
    Json(body): Json<Value>,
) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Repository::upsert(&mut conn, &user, &kind, Some(key), body).await
}
async fn delete(
    State(state): State<Shared>,
    headers: HeaderMap,
    Path((kind, key)): Path<(String, u64)>,
) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Repository::delete(&mut conn, &user, &kind, key).await
}
async fn grades(
    State(state): State<Shared>,
    headers: HeaderMap,
    Path(key): Path<u64>,
    Json(body): Json<Value>,
) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Repository::grades(&mut conn, &user, key, body).await
}
async fn close(
    State(state): State<Shared>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> ApiResult {
    let (mut conn, user) = state.repo.authenticate_connection(&token(&headers)).await?;
    Repository::close(&mut conn, &user, text(&body, "semestre")).await
}
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let _ = dotenvy::from_filename(".env.local");
    let url=std::env::var("DATABASE_URL").map_err(|_|"Configure .env.local e execute o script de instalação no MySQL Workbench. O sistema exige conexão com MySQL.")?;
    let repo=Repository::connect(&url).await.map_err(|_|"Não foi possível conectar ao MySQL com TLS. Execute a instalação no Workbench e confira .env.local.")?;
    let state = Arc::new(App {
        repo,
        attempts: Mutex::new(HashMap::new()),
    });
    let app = Router::new()
        .route(
            "/",
            get(|| async { Html(include_str!("../web/index.html")) }),
        )
        .route(
            "/app.css",
            get(|| async {
                (
                    [(header::CONTENT_TYPE, "text/css; charset=utf-8")],
                    include_str!("../web/app.css"),
                )
            }),
        )
        .route(
            "/app.js",
            get(|| async {
                (
                    [(header::CONTENT_TYPE, "text/javascript; charset=utf-8")],
                    include_str!("../web/app.js"),
                )
            }),
        )
        .route("/theme.js", get(|| async {
            ([(header::CONTENT_TYPE, "text/javascript; charset=utf-8")], include_str!("../web/theme.js"))
        }))
        .route("/intro.mp4", get(|| async {
            ([(header::CONTENT_TYPE, "video/mp4")], &include_bytes!("../web/intro.mp4")[..])
        }))
        .route("/api/login", post(login))
        .route("/api/logout", post(logout))
        .route("/api/me", get(me))
        .route("/api/data", get(data))
        .route("/api/records/{kind}", post(create))
        .route(
            "/api/records/{kind}/{id}",
            axum::routing::put(update).delete(delete),
        )
        .route("/api/grades/{id}", post(grades))
        .route("/api/close", post(close))
        .with_state(state)
        .layer(axum::middleware::map_response(security_headers));

    let port = std::env::var("SGA_PORT").unwrap_or_else(|_| "3030".into());
    let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{port}")).await?;
    println!("SGA | Faculdade do Bug Infinito\nAbra http://127.0.0.1:{port}\nPersistência: MySQL conectado por TLS. Sem armazenamento JSON.");
    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await?;
    Ok(())
}
