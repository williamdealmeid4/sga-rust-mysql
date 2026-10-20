//! MySQL is the authoritative persistence layer. Network operations use CALL only.
use crate::domain::{self, id, text, AcademicSnapshot};
use crate::{ApiError, ApiResult};
use axum::{http::StatusCode, Json};
use serde_json::{json, Value};
use sqlx::{
    mysql::{MySqlConnectOptions, MySqlPoolOptions, MySqlRow, MySqlSslMode},
    pool::PoolConnection,
    MySql, MySqlPool, Row,
};
use std::{collections::BTreeMap, str::FromStr, time::Duration};
#[derive(Clone)]
pub struct Repository {
    pub pool: MySqlPool,
}
pub fn db_error(e: sqlx::Error) -> ApiError {
    eprintln!("MySQL: {e}");
    if let Some(db) = e.as_database_error() {
        let number = db
            .try_downcast_ref::<sqlx::mysql::MySqlDatabaseError>()
            .map(|e| e.number())
            .unwrap_or(0);
        let message = match number {
            1644 => db.message().to_owned(),
            1062 => "Já existe um registro com este CPF, e-mail, RA, nome ou vínculo.".into(),
            1451 => "Este registro está vinculado a outros dados e deve ser preservado.".into(),
            1452 => {
                "O registro relacionado não existe mais. Atualize a tela e tente novamente.".into()
            }
            3819 => "Valor inválido: confira notas de 0 a 10, campos e limites do cadastro.".into(),
            1213 | 1205 => "Outra operação está alterando estes dados. Tente novamente.".into(),
            _ => "O MySQL recusou a operação. Confira os campos e a configuração do banco.".into(),
        };
        let status = if number == 1644 && message.contains("Coordenador") {
            StatusCode::FORBIDDEN
        } else {
            StatusCode::BAD_REQUEST
        };
        return ApiError(status, message);
    }
    ApiError(
        StatusCode::SERVICE_UNAVAILABLE,
        "Não foi possível comunicar com o MySQL. Confira se o serviço está ligado.".into(),
    )
}
fn json_row(row: &MySqlRow) -> Result<Value, ApiError> {
    if let Ok(sqlx::types::Json(value)) = row.try_get::<sqlx::types::Json<Value>, _>(0) {
        return Ok(value);
    }
    let raw = row.try_get_unchecked::<String, _>(0).map_err(db_error)?;
    serde_json::from_str(&raw).map_err(|_| {
        ApiError(
            StatusCode::INTERNAL_SERVER_ERROR,
            "Resposta inválida do banco de dados.".into(),
        )
    })
}
pub fn user_row(row: &MySqlRow) -> Result<Value, ApiError> {
    Ok(
        json!({"id":row.try_get::<u32,_>(0).map_err(db_error)?,"nome":row.try_get::<String,_>(1).map_err(db_error)?,"email":row.try_get::<String,_>(2).map_err(db_error)?,"perfil":row.try_get::<String,_>(3).map_err(db_error)?}),
    )
}
impl Repository {
    pub async fn connect(url: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let opts = MySqlConnectOptions::from_str(url)?.ssl_mode(MySqlSslMode::Required);
        if !["127.0.0.1", "localhost", "::1"].contains(&opts.get_host()) {
            return Err(
                "Esta instalação local aceita apenas um MySQL no próprio computador.".into(),
            );
        }
        let pool = MySqlPoolOptions::new()
            .max_connections(8)
            .acquire_timeout(Duration::from_secs(8))
            .connect_with(opts)
            .await?;
        Ok(Self { pool })
    }
    pub async fn acquire(&self) -> Result<PoolConnection<MySql>, ApiError> {
        self.pool.acquire().await.map_err(db_error)
    }
    pub async fn authenticate_connection(
        &self,
        token: &str,
    ) -> Result<(PoolConnection<MySql>, Value), ApiError> {
        if token.len() != 64 || !token.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(ApiError(
                StatusCode::UNAUTHORIZED,
                "Entre no sistema para continuar.".into(),
            ));
        }
        let mut conn = self.acquire().await?;
        let row = sqlx::query("CALL sp_UsarSessao(?)")
            .bind(token)
            .fetch_one(&mut *conn)
            .await
            .map_err(|e| {
                if e.as_database_error()
                    .is_some_and(|v| v.code().is_some_and(|c| c == "45000"))
                {
                    ApiError(
                        StatusCode::UNAUTHORIZED,
                        "Sua sessão expirou. Entre novamente.".into(),
                    )
                } else {
                    db_error(e)
                }
            })?;
        Ok((conn, user_row(&row)?))
    }
    pub async fn data(conn: &mut PoolConnection<MySql>, actor: u64) -> Result<Value, ApiError> {
        let row = sqlx::query("CALL sp_dados_sistema(?)")
            .bind(actor)
            .fetch_one(&mut **conn)
            .await
            .map_err(db_error)?;
        json_row(&row)
    }
    fn snapshot(data: &Value) -> AcademicSnapshot {
        let tables: BTreeMap<String, Vec<Value>> = domain::KINDS
            .iter()
            .map(|k| {
                (
                    k.to_string(),
                    data[k].as_array().cloned().unwrap_or_default(),
                )
            })
            .collect();
        let next_id = tables
            .values()
            .flatten()
            .map(|r| id(r, "id"))
            .max()
            .unwrap_or(0)
            + 1;
        AcademicSnapshot {
            tables,
            logs: data["auditoria"].as_array().cloned().unwrap_or_default(),
            next_id,
        }
    }
    pub async fn upsert(
        conn: &mut PoolConnection<MySql>,
        user: &Value,
        kind: &str,
        key: Option<u64>,
        input: Value,
    ) -> ApiResult {
        let actor = id(user, "id");
        let coordinator = text(user, "perfil") == "Coordenador";
        let data = Self::data(conn, actor).await?;
        let mut snapshot = Self::snapshot(&data);
        let temp_id = key.unwrap_or(snapshot.next_id);
        snapshot.upsert(kind, key, input.clone(), actor, coordinator)?;
        let v = snapshot.find(kind, temp_id)?.clone();
        let row = match kind {
            "alunos" => {
                sqlx::query("CALL sp_salvar_aluno(?,?,?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(text(&v, "ra"))
                    .bind(text(&v, "nome"))
                    .bind(text(&v, "cpf"))
                    .bind(text(&v, "email"))
                    .bind(text(&v, "nascimento"))
                    .bind(id(&v, "curso_id"))
                    .bind(text(&v, "status"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "financeiro" => {
                sqlx::query("CALL sp_salvar_cobranca(?,?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(id(&v, "aluno_id"))
                    .bind(text(&v, "descricao"))
                    .bind(v["valor"].as_f64())
                    .bind(text(&v, "vencimento"))
                    .bind(text(&v, "status"))
                    .bind(v["pagamento"].as_str())
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "cursos" => {
                sqlx::query("CALL sp_salvar_curso(?,?,?,?,?)")
                    .bind(key)
                    .bind(text(&v, "nome"))
                    .bind(id(&v, "carga_horaria"))
                    .bind(text(&v, "turno"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "disciplinas" => {
                sqlx::query("CALL sp_salvar_disciplina_requisitos(?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(id(&v, "curso_id"))
                    .bind(text(&v, "nome"))
                    .bind(id(&v, "carga_horaria"))
                    .bind(id(&v, "periodo"))
                    .bind(sqlx::types::Json(v["requisitos"].clone()))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "professores" => {
                sqlx::query("CALL sp_salvar_professor(?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(text(&v, "nome"))
                    .bind(text(&v, "cpf"))
                    .bind(text(&v, "email"))
                    .bind(text(&v, "titulacao"))
                    .bind(text(&v, "admissao"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "turmas" => {
                sqlx::query("CALL sp_salvar_turma(?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(id(&v, "disciplina_id"))
                    .bind(id(&v, "professor_id"))
                    .bind(text(&v, "semestre"))
                    .bind(id(&v, "vagas"))
                    .bind(id(&v, "total_aulas"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "usuarios" => {
                sqlx::query("CALL sp_salvar_usuario(?,?,?,?,?,?,?,?)")
                    .bind(key)
                    .bind(text(&v, "nome"))
                    .bind(text(&v, "cpf"))
                    .bind(text(&v, "email"))
                    .bind(text(&v, "login"))
                    .bind(if key.is_none() || !text(&input, "senha").is_empty() {
                        v["senha_hash"].as_str()
                    } else {
                        None
                    })
                    .bind(text(&v, "perfil"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            "matriculas" => {
                if let Some(k) = key {
                    return Ok(Json(
                        data["matriculas"]
                            .as_array()
                            .and_then(|list| list.iter().find(|m| id(m, "id") == k))
                            .cloned()
                            .ok_or_else(|| {
                                ApiError(StatusCode::NOT_FOUND, "Matrícula inexistente.".into())
                            })?,
                    ));
                }
                sqlx::query("CALL sp_matricular_aluno(?,?,?)")
                    .bind(id(&v, "aluno_id"))
                    .bind(id(&v, "turma_id"))
                    .bind(actor)
                    .fetch_one(&mut **conn)
                    .await
            }
            _ => {
                return Err(ApiError(
                    StatusCode::NOT_FOUND,
                    "Cadastro inexistente.".into(),
                ))
            }
        }
        .map_err(db_error)?;
        let _field = match kind {
            "alunos" => "id_aluno",
            "cursos" => "id_curso",
            "disciplinas" => "id_disciplina",
            "professores" => "id_professor",
            "turmas" => "id_turma",
            "usuarios" => "id_usuario",
            _ => "id_matricula",
        };
        let actual = row.try_get::<u32, _>(0).map_err(db_error)? as u64;
        let refreshed = Self::data(conn, actor).await?;
        let result = refreshed[kind]
            .as_array()
            .and_then(|list| list.iter().find(|r| id(r, "id") == actual))
            .cloned()
            .unwrap_or_else(|| json!({"id":actual}));
        Ok(Json(result))
    }
    pub async fn delete(
        conn: &mut PoolConnection<MySql>,
        user: &Value,
        kind: &str,
        key: u64,
    ) -> ApiResult {
        let actor = id(user, "id");
        let data = Self::data(conn, actor).await?;
        Self::snapshot(&data).delete(kind, key, actor, text(user, "perfil") == "Coordenador")?;
        if kind == "financeiro" {
            sqlx::query("CALL sp_excluir_cobranca(?,?)")
                .bind(key)
                .bind(actor)
                .execute(&mut **conn)
                .await
                .map_err(db_error)?;
            return Ok(Json(json!({"ok":true})));
        }
        let table = match kind {
            "alunos" => "aluno",
            "cursos" => "curso",
            "disciplinas" => "disciplina",
            "professores" => "professor",
            "turmas" => "turma",
            "usuarios" => "usuario",
            "matriculas" => "matricula",
            _ => {
                return Err(ApiError(
                    StatusCode::NOT_FOUND,
                    "Cadastro inexistente.".into(),
                ))
            }
        };
        sqlx::query("CALL sp_excluir_cadastro(?,?,?)")
            .bind(table)
            .bind(key)
            .bind(actor)
            .execute(&mut **conn)
            .await
            .map_err(db_error)?;
        Ok(Json(json!({"ok":true})))
    }
    pub async fn grades(
        conn: &mut PoolConnection<MySql>,
        user: &Value,
        key: u64,
        input: Value,
    ) -> ApiResult {
        let actor = id(user, "id");
        let data = Self::data(conn, actor).await?;
        let mut snapshot = Self::snapshot(&data);
        let v = snapshot.grades(key, input, actor, text(user, "perfil") == "Coordenador")?;
        sqlx::query("CALL sp_atualizar_avaliacao(?,?,?,?,?,?)")
            .bind(key)
            .bind(v["n1"].as_f64())
            .bind(v["n2"].as_f64())
            .bind(v["exame"].as_f64())
            .bind(id(&v, "faltas"))
            .bind(actor)
            .execute(&mut **conn)
            .await
            .map_err(db_error)?;
        let refreshed = Self::data(conn, actor).await?;
        Ok(Json(
            refreshed["matriculas"]
                .as_array()
                .and_then(|list| list.iter().find(|m| id(m, "id") == key))
                .cloned()
                .ok_or_else(|| ApiError(StatusCode::NOT_FOUND, "Matrícula inexistente.".into()))?,
        ))
    }
    pub async fn close(
        conn: &mut PoolConnection<MySql>,
        user: &Value,
        semester: &str,
    ) -> ApiResult {
        let actor = id(user, "id");
        let data = Self::data(conn, actor).await?;
        Self::snapshot(&data).close(semester, text(user, "perfil") == "Coordenador")?;
        let row = sqlx::query("CALL sp_fechar_semestre(?,?)")
            .bind(semester)
            .bind(actor)
            .fetch_one(&mut **conn)
            .await
            .map_err(db_error)?;
        Ok(Json(
            json!({"turmas":row.try_get::<i32,_>(0).map_err(db_error)?}),
        ))
    }
}
