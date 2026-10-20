//! Academic rules for a fresh snapshot from MySQL. No file persistence.
use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2,
};
use chrono::{NaiveDate, Utc};
use rand_core::OsRng;
use serde_json::{json, Value};
use std::collections::BTreeMap;
pub type Result<T> = std::result::Result<T, String>;
pub const KINDS: [&str; 8] = [
    "alunos",
    "cursos",
    "disciplinas",
    "professores",
    "turmas",
    "matriculas",
    "usuarios",
    "financeiro",
];
#[derive(Clone)]
pub struct AcademicSnapshot {
    pub tables: BTreeMap<String, Vec<Value>>,
    pub logs: Vec<Value>,
    pub next_id: u64,
}
pub fn text<'a>(v: &'a Value, k: &str) -> &'a str {
    v[k].as_str().unwrap_or("")
}
pub fn id(v: &Value, k: &str) -> u64 {
    v[k].as_u64().unwrap_or(0)
}
pub fn password_hash(password: &str) -> Result<String> {
    Argon2::default()
        .hash_password(password.as_bytes(), &SaltString::generate(&mut OsRng))
        .map(|h| h.to_string())
        .map_err(|_| "Não foi possível proteger a senha.".into())
}
pub fn safe_user(mut v: Value) -> Value {
    v.as_object_mut().unwrap().remove("senha_hash");
    v
}
pub fn result_grade(
    n1: Option<f64>,
    n2: Option<f64>,
    exam: Option<f64>,
    absences: u64,
    lessons: u64,
) -> (Option<f64>, f64, &'static str) {
    let frequency = if lessons == 0 {
        0.0
    } else {
        (lessons.saturating_sub(absences)) as f64 / lessons as f64 * 100.0
    };
    let partial = n1.zip(n2).map(|(a, b)| (a + b) / 2.0);
    let average = partial.map(|p| {
        if (4.0..7.0).contains(&p) {
            exam.map(|e| (p + e) / 2.0).unwrap_or(p)
        } else {
            p
        }
    });
    let status = if frequency < 75.0 {
        "Reprovado por Falta"
    } else {
        match partial {
            None => "Cursando",
            Some(p) if p >= 7.0 => "Aprovado",
            Some(p) if p < 4.0 => "Reprovado por Nota",
            Some(_) => match average.zip(exam) {
                None => "Em Exame",
                Some((a, _)) if a >= 5.0 => "Aprovado",
                _ => "Reprovado por Nota",
            },
        }
    };
    (average, frequency, status)
}
impl AcademicSnapshot {
    pub fn rows(&self, kind: &str) -> &[Value] {
        self.tables.get(kind).map(Vec::as_slice).unwrap_or(&[])
    }
    pub fn find(&self, kind: &str, key: u64) -> Result<&Value> {
        self.rows(kind)
            .iter()
            .find(|v| id(v, "id") == key)
            .ok_or_else(|| "Registro não encontrado.".into())
    }
    #[cfg(test)]
    pub fn public(&self, coordinator: bool) -> Value {
        let mut data = json!(self.tables);
        data["matriculas"] = json!(self
            .rows("matriculas")
            .iter()
            .map(|v| self.enriched(v))
            .collect::<Vec<_>>());
        if coordinator {
            data["usuarios"] = json!(self
                .rows("usuarios")
                .iter()
                .cloned()
                .map(safe_user)
                .collect::<Vec<_>>());
            data["auditoria"] = json!(self.logs);
        } else {
            data.as_object_mut().unwrap().remove("usuarios");
        }
        data
    }
    pub fn enriched(&self, v: &Value) -> Value {
        let mut out = v.clone();
        let lessons = self
            .find("turmas", id(v, "turma_id"))
            .map(|t| id(t, "total_aulas"))
            .unwrap_or(0);
        let (avg, freq, status) = result_grade(
            v["n1"].as_f64(),
            v["n2"].as_f64(),
            v["exame"].as_f64(),
            id(v, "faltas"),
            lessons,
        );
        out["media_final"] = json!(avg);
        out["frequencia"] = json!(freq);
        out["situacao"] = json!(status);
        out
    }
    pub fn authorize(kind: &str, coordinator: bool) -> Result<()> {
        if !KINDS.contains(&kind) {
            return Err("Cadastro não encontrado.".into());
        }
        if !coordinator && !["alunos", "matriculas"].contains(&kind) {
            return Err("Este cadastro exige perfil Coordenador.".into());
        }
        Ok(())
    }
    fn positive(v: &Value, key: &str) -> Result<()> {
        if id(v, key) == 0 || id(v, key) > 100_000 {
            Err(format!("{key}: informe um inteiro entre 1 e 100000."))
        } else {
            Ok(())
        }
    }
    fn required(v: &Value, keys: &[&str]) -> Result<()> {
        for k in keys {
            if text(v, k).trim().is_empty() || text(v, k).chars().count() > 250 {
                return Err(format!("{k}: preencha com até 250 caracteres."));
            }
        }
        Ok(())
    }
    fn unique(&self, kind: &str, v: &Value, keys: &[&str]) -> Result<()> {
        for key in keys {
            if self.rows(kind).iter().any(|r| {
                id(r, "id") != id(v, "id") && text(r, key).eq_ignore_ascii_case(text(v, key))
            }) {
                return Err(format!("Já existe um registro com este {key}."));
            }
        }
        Ok(())
    }
    fn date(v: &Value, key: &str) -> Result<()> {
        let s = text(v, key);
        let date = NaiveDate::parse_from_str(s, "%Y-%m-%d")
            .map_err(|_| format!("{key}: data inválida."))?;
        if date > Utc::now().date_naive() {
            return Err(format!("{key}: não pode estar no futuro."));
        }
        Ok(())
    }
    fn required_person(&self, kind: &str, v: &Value) -> Result<()> {
        Self::required(v, &["nome", "cpf", "email"])?;
        let cpf = text(v, "cpf");
        if cpf.len() != 11 || !cpf.chars().all(|c| c.is_ascii_digit()) {
            return Err("CPF deve conter 11 números, sem pontuação.".into());
        }
        let email = text(v, "email");
        if !email
            .split_once('@')
            .is_some_and(|(a, b)| !a.is_empty() && b.contains('.') && !b.ends_with('.'))
            || email.contains(' ')
        {
            return Err("Informe um e-mail válido.".into());
        }
        self.unique(kind, v, &["cpf", "email"])
    }
    fn reaches(&self, start: u64, target: u64, seen: &mut Vec<u64>) -> bool {
        if start == target {
            return true;
        }
        if seen.contains(&start) {
            return false;
        }
        seen.push(start);
        self.find("disciplinas", start)
            .ok()
            .and_then(|s| s["requisitos"].as_array())
            .is_some_and(|list| {
                list.iter()
                    .any(|r| self.reaches(r.as_u64().unwrap_or(0), target, seen))
            })
    }
    fn validate(&self, kind: &str, v: &Value, old: Option<&Value>) -> Result<()> {
        match kind {
            "financeiro" => {
                self.find("alunos", id(v, "aluno_id"))?;
                Self::required(v, &["descricao", "vencimento", "status"])?;
                NaiveDate::parse_from_str(text(v, "vencimento"), "%Y-%m-%d")
                    .map_err(|_| "Vencimento inválido.")?;
                let amount = v["valor"].as_f64().ok_or("Informe o valor da cobrança.")?;
                if !amount.is_finite()
                    || amount <= 0.0
                    || amount > 1_000_000.0
                    || (amount * 100.0 - (amount * 100.0).round()).abs() > 0.000001
                {
                    return Err("Valor deve ser positivo, com até duas casas decimais.".into());
                }
                if !["Pendente", "Pago", "Cancelado"].contains(&text(v, "status")) {
                    return Err("Status financeiro inválido.".into());
                }
                if text(v, "status") == "Pago" {
                    Self::date(v, "pagamento")?;
                } else if !v["pagamento"].is_null() {
                    return Err("Informe pagamento apenas quando o status for Pago.".into());
                }
                if old.is_some_and(|o| o["aluno_id"] != v["aluno_id"]) {
                    return Err("O aluno da cobrança não pode ser alterado.".into());
                }
            }
            "cursos" => {
                Self::required(v, &["nome", "turno"])?;
                Self::positive(v, "carga_horaria")?;
                if !["Matutino", "Vespertino", "Noturno"].contains(&text(v, "turno")) {
                    return Err("Turno inválido.".into());
                }
                self.unique(kind, v, &["nome"])?;
            }
            "alunos" => {
                self.required_person(kind, v)?;
                Self::required(v, &["ra", "status", "nascimento"])?;
                Self::date(v, "nascimento")?;
                self.find("cursos", id(v, "curso_id"))?;
                self.unique(kind, v, &["ra"])?;
                if !["Ativo", "Trancado", "Formado"].contains(&text(v, "status")) {
                    return Err("Status de aluno inválido.".into());
                }
                if old.is_some_and(|o| o["curso_id"] != v["curso_id"])
                    && self
                        .rows("matriculas")
                        .iter()
                        .any(|m| id(m, "aluno_id") == id(v, "id"))
                {
                    return Err("Aluno com matrículas não pode trocar de curso.".into());
                }
            }
            "professores" => {
                self.required_person(kind, v)?;
                Self::required(v, &["titulacao", "admissao"])?;
                Self::date(v, "admissao")?;
            }
            "usuarios" => {
                self.required_person(kind, v)?;
                Self::required(v, &["login", "perfil"])?;
                self.unique(kind, v, &["login"])?;
                if !["Coordenador", "Secretario"].contains(&text(v, "perfil")) {
                    return Err("Perfil inválido.".into());
                }
                if old.is_some_and(|o| text(o, "perfil") == "Coordenador")
                    && text(v, "perfil") != "Coordenador"
                    && self
                        .rows(kind)
                        .iter()
                        .filter(|u| text(u, "perfil") == "Coordenador")
                        .count()
                        == 1
                {
                    return Err("Mantenha ao menos um Coordenador.".into());
                }
            }
            "disciplinas" => {
                Self::required(v, &["nome"])?;
                Self::positive(v, "periodo")?;
                Self::positive(v, "carga_horaria")?;
                self.find("cursos", id(v, "curso_id"))?;
                if old.is_some_and(|o| o["curso_id"] != v["curso_id"])
                    && self
                        .rows("turmas")
                        .iter()
                        .any(|t| id(t, "disciplina_id") == id(v, "id"))
                {
                    return Err("Disciplina com turmas não pode trocar de curso.".into());
                }
                let req = v["requisitos"]
                    .as_array()
                    .ok_or("Lista de pré-requisitos inválida.")?;
                let mut unique = Vec::new();
                for r in req {
                    let key = r.as_u64().ok_or("Pré-requisito inválido.")?;
                    let subject = self.find("disciplinas", key)?;
                    if unique.contains(&key) {
                        return Err("Pré-requisito duplicado.".into());
                    }
                    unique.push(key);
                    if subject["curso_id"] != v["curso_id"] {
                        return Err("Pré-requisito deve pertencer ao mesmo curso.".into());
                    }
                    if self.reaches(key, id(v, "id"), &mut Vec::new()) {
                        return Err("Pré-requisitos não podem formar ciclos.".into());
                    }
                }
            }
            "turmas" => {
                Self::required(v, &["semestre"])?;
                let s = text(v, "semestre");
                let parts: Vec<_> = s.split('.').collect();
                if parts.len() != 2
                    || parts[0].len() != 4
                    || parts[0].parse::<u16>().is_err()
                    || !["1", "2"].contains(&parts[1])
                {
                    return Err("Semestre deve seguir o formato 2026.1 ou 2026.2.".into());
                }
                self.find("disciplinas", id(v, "disciplina_id"))?;
                self.find("professores", id(v, "professor_id"))?;
                Self::positive(v, "vagas")?;
                Self::positive(v, "total_aulas")?;
                let enrolled: Vec<_> = self
                    .rows("matriculas")
                    .iter()
                    .filter(|m| id(m, "turma_id") == id(v, "id"))
                    .collect();
                if enrolled.len() as u64 > id(v, "vagas") {
                    return Err("Vagas não podem ser menores que o total de matriculados.".into());
                }
                if enrolled
                    .iter()
                    .any(|m| id(m, "faltas") > id(v, "total_aulas"))
                {
                    return Err(
                        "Total de aulas não pode ser menor que faltas já registradas.".into(),
                    );
                }
                if let Some(o) = old {
                    if o["encerrada"] == true {
                        return Err("Turma encerrada não pode ser alterada.".into());
                    }
                    if !enrolled.is_empty()
                        && (o["disciplina_id"] != v["disciplina_id"]
                            || o["semestre"] != v["semestre"])
                    {
                        return Err(
                            "Turma com matrículas não pode trocar de disciplina ou semestre."
                                .into(),
                        );
                    }
                }
            }
            "matriculas" => {
                let student = self.find("alunos", id(v, "aluno_id"))?;
                let class = self.find("turmas", id(v, "turma_id"))?;
                if old.is_some_and(|o| {
                    o["aluno_id"] != v["aluno_id"] || o["turma_id"] != v["turma_id"]
                }) {
                    return Err(
                        "Para trocar aluno ou turma, cancele a matrícula e crie outra.".into(),
                    );
                }
                if class["encerrada"] == true {
                    return Err("Esta turma está encerrada.".into());
                }
                if text(student, "status") != "Ativo" {
                    return Err("Somente alunos Ativos podem realizar novas matrículas.".into());
                }
                let subject = self.find("disciplinas", id(class, "disciplina_id"))?;
                if student["curso_id"] != subject["curso_id"] {
                    return Err("A turma deve pertencer ao curso do aluno.".into());
                }
                let others: Vec<_> = self
                    .rows(kind)
                    .iter()
                    .filter(|m| id(m, "id") != id(v, "id") && m["turma_id"] == v["turma_id"])
                    .collect();
                if others.iter().any(|m| m["aluno_id"] == v["aluno_id"]) {
                    return Err("Este aluno já está matriculado na turma.".into());
                }
                if others.len() as u64 >= id(class, "vagas") {
                    return Err("Turma lotada: não há vagas disponíveis.".into());
                }
                for req in subject["requisitos"].as_array().into_iter().flatten() {
                    let passed = self.rows(kind).iter().any(|m| {
                        m["aluno_id"] == v["aluno_id"]
                            && self.find("turmas", id(m, "turma_id")).is_ok_and(|t| {
                                t["disciplina_id"] == *req
                                    && text(t, "semestre") < text(class, "semestre")
                            })
                            && self.enriched(m)["situacao"] == "Aprovado"
                    });
                    if !passed {
                        return Err(format!(
                            "Falta aprovação no pré-requisito: {}.",
                            self.find("disciplinas", req.as_u64().unwrap_or(0))
                                .map(|s| text(s, "nome"))
                                .unwrap_or("disciplina")
                        ));
                    }
                }
            }
            _ => return Err("Cadastro inválido.".into()),
        }
        Ok(())
    }

    pub fn upsert(
        &mut self,
        kind: &str,
        key: Option<u64>,
        input: Value,
        actor: u64,
        coordinator: bool,
    ) -> Result<Value> {
        Self::authorize(kind, coordinator)?;
        let fields: &[&str] = match kind {
            "financeiro" => &[
                "aluno_id",
                "descricao",
                "valor",
                "vencimento",
                "status",
                "pagamento",
            ],
            "alunos" => &[
                "ra",
                "nome",
                "cpf",
                "email",
                "nascimento",
                "curso_id",
                "status",
            ],
            "cursos" => &["nome", "carga_horaria", "turno"],
            "disciplinas" => &["nome", "curso_id", "carga_horaria", "periodo", "requisitos"],
            "professores" => &["nome", "cpf", "email", "titulacao", "admissao"],
            "turmas" => &[
                "disciplina_id",
                "professor_id",
                "semestre",
                "vagas",
                "total_aulas",
            ],
            "matriculas" => &["aluno_id", "turma_id"],
            "usuarios" => &["nome", "cpf", "email", "login", "perfil", "senha"],
            _ => &[],
        };
        let obj = input.as_object().ok_or("Dados inválidos.")?;
        if obj.keys().any(|k| !fields.contains(&k.as_str())) {
            return Err("O formulário contém campos não permitidos.".into());
        }
        let old = key.map(|k| self.find(kind, k).cloned()).transpose()?;
        let mut value = old.clone().unwrap_or_else(|| json!({"id":self.next_id}));
        for (k, v) in obj {
            value[k] = if k == "senha" {
                v.clone()
            } else if let Some(s) = v.as_str() {
                json!(s.trim())
            } else {
                v.clone()
            };
        }
        if kind == "disciplinas" && value["requisitos"].is_null() {
            value["requisitos"] = json!([]);
        }
        if kind == "turmas" && old.is_none() {
            value["encerrada"] = json!(false);
        }
        if kind == "matriculas" && old.is_none() {
            for k in ["n1", "n2", "exame"] {
                value[k] = Value::Null;
            }
            value["faltas"] = json!(0);
            value["usuario_id"] = json!(actor);
            value["data"] = json!(Utc::now().format("%Y-%m-%d").to_string());
        }
        if kind == "financeiro" {
            if text(&value, "pagamento").is_empty() {
                value["pagamento"] = Value::Null;
            }
            if old.is_none() {
                value["curso_id"] =
                    self.find("alunos", id(&value, "aluno_id"))?["curso_id"].clone();
            }
        }
        self.validate(kind, &value, old.as_ref())?;
        if kind == "usuarios" {
            let password = text(&value, "senha");
            if !password.is_empty() {
                if password.len() < 8 || password.len() > 128 {
                    return Err("A senha deve ter de 8 a 128 caracteres.".into());
                }
                value["senha_hash"] = json!(password_hash(password)?);
            } else if old.is_none() {
                return Err("Informe uma senha com ao menos 8 caracteres.".into());
            }
            value.as_object_mut().unwrap().remove("senha");
        }
        let rows = self.tables.get_mut(kind).unwrap();
        if let Some(k) = key {
            *rows.iter_mut().find(|r| id(r, "id") == k).unwrap() = value.clone();
        } else {
            rows.push(value.clone());
            self.next_id += 1;
        }
        Ok(if kind == "usuarios" {
            safe_user(value)
        } else {
            value
        })
    }
    pub fn delete(&mut self, kind: &str, key: u64, actor: u64, coordinator: bool) -> Result<()> {
        Self::authorize(kind, coordinator)?;
        let value = self.find(kind, key)?.clone();
        if kind == "usuarios" && key == actor {
            return Err("Você não pode excluir seu próprio acesso.".into());
        }
        if kind == "usuarios"
            && text(&value, "perfil") == "Coordenador"
            && self
                .rows(kind)
                .iter()
                .filter(|u| text(u, "perfil") == "Coordenador")
                .count()
                == 1
        {
            return Err("Mantenha ao menos um Coordenador.".into());
        }
        if kind == "turmas" && value["encerrada"] == true {
            return Err("Turma encerrada não pode ser excluída.".into());
        }
        if kind == "matriculas" {
            if self.find("turmas", id(&value, "turma_id"))?["encerrada"] == true {
                return Err("Não é possível cancelar matrícula de turma encerrada.".into());
            }
            if ["n1", "n2", "exame"].iter().any(|k| !value[k].is_null())
                || self.logs.iter().any(|l| id(l, "matricula_id") == key)
            {
                return Err(
                    "Matrícula com notas ou auditoria deve ser preservada no histórico.".into(),
                );
            }
        }
        let links: &[(&str, &str)] = match kind {
            "alunos" => &[("matriculas", "aluno_id")],
            "cursos" => &[("alunos", "curso_id"), ("disciplinas", "curso_id")],
            "disciplinas" => &[("turmas", "disciplina_id")],
            "professores" => &[("turmas", "professor_id")],
            "turmas" => &[("matriculas", "turma_id")],
            "usuarios" => &[("matriculas", "usuario_id")],
            _ => &[],
        };
        for (table, field) in links {
            if self.rows(table).iter().any(|r| id(r, field) == key) {
                return Err(format!(
                    "Este registro está vinculado a {table}. Remova os vínculos primeiro."
                ));
            }
        }
        if kind == "disciplinas"
            && self.rows(kind).iter().any(|s| {
                s["requisitos"]
                    .as_array()
                    .is_some_and(|r| r.contains(&json!(key)))
            })
        {
            return Err("Disciplina usada como pré-requisito não pode ser excluída.".into());
        }
        self.tables
            .get_mut(kind)
            .unwrap()
            .retain(|r| id(r, "id") != key);
        Ok(())
    }
    pub fn grades(
        &mut self,
        key: u64,
        input: Value,
        actor: u64,
        coordinator: bool,
    ) -> Result<Value> {
        if !coordinator {
            return Err("Somente o Coordenador pode lançar notas.".into());
        }
        let old = self.find("matriculas", key)?.clone();
        let class = self.find("turmas", id(&old, "turma_id"))?;
        if class["encerrada"] == true {
            return Err("Turma encerrada: lançamento bloqueado.".into());
        }
        let mut v = old.clone();
        let obj = input.as_object().ok_or("Notas inválidas.")?;
        if obj
            .keys()
            .any(|k| !["n1", "n2", "exame", "faltas"].contains(&k.as_str()))
        {
            return Err("Campo de lançamento inválido.".into());
        }
        for k in ["n1", "n2", "exame"] {
            if let Some(note) = obj.get(k) {
                if !note.is_null()
                    && !note
                        .as_f64()
                        .is_some_and(|n| n.is_finite() && (0.0..=10.0).contains(&n))
                {
                    return Err("As notas devem estar entre 0 e 10.".into());
                }
                v[k] = note.clone();
            }
        }
        if let Some(f) = obj.get("faltas") {
            if !f.as_u64().is_some_and(|n| n <= id(class, "total_aulas")) {
                return Err("Faltas devem ser um inteiro entre zero e o total de aulas.".into());
            }
            v["faltas"] = f.clone();
        }
        let partial = v["n1"]
            .as_f64()
            .zip(v["n2"].as_f64())
            .map(|(a, b)| (a + b) / 2.0);
        if !v["exame"].is_null()
            && (!partial.is_some_and(|p| (4.0..7.0).contains(&p))
                || self.enriched(&v)["frequencia"].as_f64().unwrap_or(0.0) < 75.0)
        {
            return Err(
                "Exame permitido apenas com média parcial entre 4 e 7 e frequência mínima de 75%."
                    .into(),
            );
        }
        for k in ["n1", "n2", "exame", "faltas"] {
            if v[k] != old[k] {
                self.logs.push(json!({"id":self.next_id,"matricula_id":key,"campo":k,"anterior":old[k],"novo":v[k],"usuario_id":actor,"usuario":self.find("usuarios",actor).map(|u|text(u,"nome")).unwrap_or("Sistema"),"data_hora":Utc::now().to_rfc3339()}));
                self.next_id += 1;
            }
        }
        *self
            .tables
            .get_mut("matriculas")
            .unwrap()
            .iter_mut()
            .find(|m| id(m, "id") == key)
            .unwrap() = v.clone();
        Ok(self.enriched(&v))
    }
    pub fn close(&mut self, semester: &str, coordinator: bool) -> Result<usize> {
        if !coordinator {
            return Err("Somente o Coordenador pode encerrar semestres.".into());
        }
        let classes: Vec<_> = self
            .rows("turmas")
            .iter()
            .filter(|t| text(t, "semestre") == semester && t["encerrada"] != true)
            .map(|t| id(t, "id"))
            .collect();
        if classes.is_empty() {
            return Err("Não há turmas abertas neste semestre.".into());
        }
        for m in self
            .rows("matriculas")
            .iter()
            .filter(|m| classes.contains(&id(m, "turma_id")))
        {
            let enriched = self.enriched(m);
            if ["Cursando", "Em Exame"].contains(&text(&enriched, "situacao")) {
                return Err("Há matrículas com notas ou exames pendentes. Conclua os lançamentos antes de encerrar.".into());
            }
        }
        for t in self.tables.get_mut("turmas").unwrap() {
            if classes.contains(&id(t, "id")) {
                t["encerrada"] = json!(true);
            }
        }
        Ok(classes.len())
    }

    #[cfg(test)]
    pub fn seed() -> Result<Self> {
        let mut db = Self {
            tables: KINDS.iter().map(|k| (k.to_string(), vec![])).collect(),
            logs: vec![],
            next_id: 1000,
        };
        let pass = password_hash("Fbi@2026")?;
        for (i, name) in [
            "Helena Martins",
            "Rafael Costa",
            "Marina Alves",
            "Lucas Ribeiro",
            "Camila Rocha",
        ]
        .iter()
        .enumerate()
        {
            db.tables.get_mut("usuarios").unwrap().push(json!({"id":i+1,"nome":name,"cpf":format!("91000000{:03}",i+1),"email":format!("usuario{}@fbi.edu.br",i+1),"login":(["coordenador","coordenador2","secretario","secretario2","secretario3"][i]),"perfil":if i<2 {"Coordenador"}else{"Secretario"},"senha_hash":pass}));
        }
        for (i, (name, hours, shift)) in [
            ("Sistemas de Informação", 3200, "Noturno"),
            ("Administração", 3000, "Matutino"),
            ("Engenharia de Software", 3600, "Noturno"),
        ]
        .iter()
        .enumerate()
        {
            db.tables
                .get_mut("cursos")
                .unwrap()
                .push(json!({"id":i+1,"nome":name,"carga_horaria":hours,"turno":shift}));
        }
        for (i, (name, course, period)) in [
            ("Algoritmos e Programação", 1, 1),
            ("Banco de Dados I", 1, 2),
            ("Banco de Dados II", 1, 3),
            ("Fundamentos de Gestão", 2, 1),
            ("Gestão de Pessoas", 2, 2),
            ("Engenharia de Requisitos", 3, 1),
        ]
        .iter()
        .enumerate()
        {
            db.tables.get_mut("disciplinas").unwrap().push(json!({"id":i+1,"nome":name,"curso_id":course,"carga_horaria":80,"periodo":period,"requisitos":if i==2 {vec![2]} else {vec![]}}));
        }
        for (i, name) in [
            "Ana Beatriz Souza",
            "Carlos Eduardo Lima",
            "Fernanda Oliveira",
            "Pedro Henrique Melo",
            "Juliana Nascimento",
        ]
        .iter()
        .enumerate()
        {
            db.tables.get_mut("professores").unwrap().push(json!({"id":i+1,"nome":name,"cpf":format!("82000000{:03}",i+1),"email":format!("docente{}@fbi.edu.br",i+1),"titulacao":if i%2==0 {"Doutorado"}else{"Mestrado"},"admissao":"2022-02-01"}));
        }
        let names = [
            "Alice Fernandes",
            "Bruno Carvalho",
            "Clara Mendes",
            "Daniel Santos",
            "Eduarda Lima",
            "Felipe Rodrigues",
            "Gabriela Azevedo",
            "Henrique Barros",
            "Isabela Duarte",
            "João Vitor Silva",
            "Laura Teixeira",
            "Matheus Almeida",
            "Natália Pereira",
            "Otávio Gomes",
            "Paula Monteiro",
            "Renan Cardoso",
            "Sofia Batista",
            "Thiago Correia",
            "Valentina Dias",
            "Vinícius Freitas",
        ];
        for (i, name) in names.iter().enumerate() {
            db.tables.get_mut("alunos").unwrap().push(json!({"id":i+1,"ra":format!("2026{:04}",i+1),"nome":name,"cpf":format!("73000000{:03}",i+1),"email":format!("aluno{}@fbi.edu.br",i+1),"nascimento":format!("2004-{:02}-15",i%12+1),"curso_id":if i<12 {1}else{2},"status":if i==19 {"Trancado"}else{"Ativo"}}));
        }
        for (i, subject) in [1, 2, 3, 4, 5].iter().enumerate() {
            db.tables.get_mut("turmas").unwrap().push(json!({"id":i+1,"disciplina_id":subject,"professor_id":i+1,"semestre":if i==1 {"2026.1"}else{"2026.2"},"vagas":30,"total_aulas":80,"encerrada":false}));
        }
        for student in 1..=12 {
            for class in [1, 2] {
                let idx = db.rows("matriculas").len() as u64;
                db.tables.get_mut("matriculas").unwrap().push(json!({"id":idx+1,"aluno_id":student,"turma_id":class,"data":"2026-07-20","n1":if class==2 {Some(8.0)}else{Some(4.0+(student%6) as f64)},"n2":if class==2 {Some(7.5)}else{Some(4.0+(student%5) as f64)},"exame":null,"faltas":student%5,"usuario_id":3}));
            }
        }
        for student in 13..=19 {
            let key = db.rows("matriculas").len() + 1;
            db.tables.get_mut("matriculas").unwrap().push(json!({"id":key,"aluno_id":student,"turma_id":4,"data":"2026-07-20","n1":8.0,"n2":7.0,"exame":null,"faltas":4,"usuario_id":3}));
        }
        for student in 13..=16 {
            let key = db.rows("matriculas").len() + 1;
            db.tables.get_mut("matriculas").unwrap().push(json!({"id":key,"aluno_id":student,"turma_id":5,"data":"2026-07-20","n1":null,"n2":null,"exame":null,"faltas":0,"usuario_id":3}));
        }
        Ok(db)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn grade_boundaries() {
        for (n1, n2, exam, faults, status, avg) in [
            (7., 7., None, 20, "Aprovado", 7.),
            (6.99, 6.99, None, 0, "Em Exame", 6.99),
            (4., 4., None, 0, "Em Exame", 4.),
            (3.99, 3.99, None, 0, "Reprovado por Nota", 3.99),
            (6., 6., Some(4.), 0, "Aprovado", 5.),
            (4., 4., Some(5.), 0, "Reprovado por Nota", 4.5),
            (9., 9., None, 21, "Reprovado por Falta", 9.),
        ] {
            let (a, _, s) = result_grade(Some(n1), Some(n2), exam, faults, 80);
            assert_eq!(s, status);
            assert!((a.unwrap() - avg).abs() < 0.0001);
        }
        assert_eq!(result_grade(None, None, None, 0, 80).2, "Cursando");
    }
    #[test]
    fn enrollment_constraints() {
        let mut d = AcademicSnapshot::seed().unwrap();
        assert!(d
            .upsert(
                "matriculas",
                None,
                json!({"aluno_id":20,"turma_id":4}),
                3,
                false
            )
            .unwrap_err()
            .contains("Ativos"));
        assert!(d
            .upsert(
                "matriculas",
                None,
                json!({"aluno_id":1,"turma_id":1}),
                3,
                false
            )
            .unwrap_err()
            .contains("já está"));
        d.tables.get_mut("turmas").unwrap()[0]["vagas"] = json!(12);
        d.tables
            .get_mut("alunos")
            .unwrap()
            .push(json!({"id":99,"nome":"Teste","curso_id":1,"status":"Ativo"}));
        assert!(d
            .upsert(
                "matriculas",
                None,
                json!({"aluno_id":99,"turma_id":1}),
                3,
                false
            )
            .unwrap_err()
            .contains("lotada"));
        assert!(d
            .upsert(
                "matriculas",
                None,
                json!({"aluno_id":99,"turma_id":3}),
                3,
                false
            )
            .unwrap_err()
            .contains("pré-requisito"));
        assert!(d
            .upsert(
                "matriculas",
                None,
                json!({"aluno_id":1,"turma_id":3}),
                3,
                false
            )
            .is_ok());
    }
    #[test]
    fn grades_audit_and_permissions() {
        let mut d = AcademicSnapshot::seed().unwrap();
        assert!(d.grades(1, json!({"n1":11}), 1, true).is_err());
        assert!(d.logs.is_empty());
        assert!(d.grades(1, json!({"n1":9}), 3, false).is_err());
        let v = d
            .grades(1, json!({"n1":9,"n2":9,"faltas":21}), 1, true)
            .unwrap();
        assert_eq!(v["situacao"], "Reprovado por Falta");
        assert_eq!(d.logs.len(), 3);
        assert!(d.upsert("cursos", None, json!({}), 3, false).is_err());
        assert!(d.close("2026.2", false).is_err());
        assert!(d.public(false).get("usuarios").is_none());
        assert!(!d.public(true).to_string().contains("senha_hash"));
        assert!(d
            .upsert("matriculas", Some(1), json!({"n1":10}), 3, false)
            .is_err());
    }
    #[test]
    fn examination_and_closure() {
        let mut d = AcademicSnapshot::seed().unwrap();
        d.grades(1, json!({"n1":6,"n2":6,"exame":4}), 1, true)
            .unwrap();
        assert_eq!(
            d.enriched(d.find("matriculas", 1).unwrap())["situacao"],
            "Aprovado"
        );
        assert!(d.grades(1, json!({"n1":9}), 1, true).is_err());
        assert!(d.close("2026.2", true).is_err());
        let count = d.close("2026.1", true).unwrap();
        assert_eq!(count, 1);
        assert!(d
            .grades(2, json!({"n1":9}), 1, true)
            .unwrap_err()
            .contains("encerrada"));
    }
    #[test]
    fn referential_integrity_and_cycles() {
        let mut d = AcademicSnapshot::seed().unwrap();
        assert!(d.delete("alunos", 1, 1, true).is_err());
        assert!(d.delete("usuarios", 1, 1, true).is_err());
        assert!(d.delete("disciplinas", 2, 1, true).is_err());
        assert!(d
            .upsert("disciplinas", Some(2), json!({"requisitos":[3]}), 1, true)
            .unwrap_err()
            .contains("ciclos"));
        assert!(d
            .upsert("turmas", Some(1), json!({"vagas":1}), 1, true)
            .is_err());
        assert_eq!(d.rows("matriculas").len(), 35);
    }
}
