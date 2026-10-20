import grt,json,traceback
from pathlib import Path
root=Path(__file__).resolve().parents[1]
log=root/"database/.diagram_build.json"
result={}
try:
 result["model_methods"]=str(grt.classes.workbench_physical_Model.__grtmethods__)
 result["diagram_methods"]=str(grt.classes.workbench_physical_Diagram.__grtmethods__)
 grt.modules.Workbench.newDocument()
 model=grt.root.wb.doc.physicalModels[0]
 sql=(root/"database/00_criar_banco.sql").read_text(encoding="utf-8")+"\n"+(root/"database/01_estrutura.sql").read_text(encoding="utf-8")
 sql+="\n"+(root/"database/07_financeiro.sql").read_text(encoding="utf-8").split("DELIMITER")[0]
 sql=sql.replace("DEFAULT(UTC_TIMESTAMP(6))","DEFAULT CURRENT_TIMESTAMP(6)")
 sql=sql.replace("DEFAULT (UTC_TIMESTAMP(6))","DEFAULT CURRENT_TIMESTAMP(6)").replace("DEFAULT(UTC_TIMESTAMP(6))","DEFAULT CURRENT_TIMESTAMP(6)")
 result["parse_result"]=grt.modules.MysqlSqlFacade.parseSqlScriptString(model.catalog,sql)
 for schema in list(model.catalog.schemata):
  if schema.name!="sga_fbi" and len(schema.tables)==0:model.catalog.schemata.remove(schema)
 result["schemas"]=[s.name for s in model.catalog.schemata]
 diagram=model.addNewDiagram(0)
 diagram.name="SGA - Relacionamentos academicos"
 positions={"cobranca":(40,830),"log_financeiro":(40,1250),"curso":(40,70),"disciplina":(380,70),"pre_requisito":(720,70),"professor":(1060,70),"aluno":(40,430),"turma":(720,430),"matricula":(380,830),"usuario":(1060,430),"log_nota":(720,830),"sessao_usuario":(1060,830)}
 for schema in model.catalog.schemata:
  for table in schema.tables:
   x,y=positions.get(table.name,(40,1200))
   figure=diagram.placeTable(table,x,y)
   figure.width=280
   if table.name=="log_nota":
    for col in table.columns:
     if col.name=="data_hora":col.defaultValue="(UTC_TIMESTAMP(6))"
 diagram.width=1450
 diagram.height=1650
 result["tables"]=[t.name for schema in model.catalog.schemata for t in schema.tables]
 result["figures"]=len(diagram.figures)
 result["connections"]=len(diagram.connections)
 output=root/"database/SGA-diagrama.mwb"
 grt.modules.Workbench.saveModelAs(str(output))
 result["output"]=str(output)
except Exception:result["error"]=traceback.format_exc()
log.write_text(json.dumps(result,indent=2),encoding="utf-8")
