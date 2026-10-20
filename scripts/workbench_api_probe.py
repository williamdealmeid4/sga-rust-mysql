import grt,json,traceback
from pathlib import Path
p=Path(r"C:\Users\Willi\Documents\SGA-Rust\database\.workbench_api.json")
try:
 result={"Workbench":dir(grt.modules.Workbench),"DbMySQL":dir(grt.modules.DbMySQL),"Model":dir(grt.classes.workbench_physical_Model),"Diagram":dir(grt.classes.workbench_physical_Diagram),"doc_present":bool(grt.root.wb.doc)}
 p.write_text(json.dumps(result,indent=2),encoding="utf-8")
except Exception:p.write_text(traceback.format_exc(),encoding="utf-8")
