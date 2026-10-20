"""Rebuild the code graph with Graphify, reusing the delegated PDF extraction."""
import json
from collections import defaultdict
from pathlib import Path
from graphify.detect import detect,save_manifest
from graphify.extract import collect_files,extract
from graphify.build import build_from_json
from graphify.cluster import cluster,score_all
from graphify.analyze import god_nodes,surprising_connections,suggest_questions
from graphify.report import generate
from graphify.export import to_json
from graphify.diagnostics import diagnose_extraction,format_diagnostic_report
root=Path(__file__).resolve().parents[1];out=root/'graphify-out';source=root/'docs/requisitos.pdf'
sem=json.loads((out/'semantic_requirements.json').read_text(encoding='utf-8'))
code=collect_files(root/'src')+collect_files(root/'web')
ast=extract(code,cache_root=root)
nodes=ast['nodes']+sem['nodes'];raw_edges=ast['edges']+sem['edges']
raw={'nodes':nodes,'edges':raw_edges,'hyperedges':sem.get('hyperedges',[]),'input_tokens':0,'output_tokens':0}
(out/'extraction_raw.json').write_text(json.dumps(raw,ensure_ascii=False,indent=2),encoding='utf-8')
# Simple-graph view: retain every original relation in provenance, exclude unresolved
# endpoints, and represent recursive edges as attributes. Raw extraction stays intact.
node_ids={n['id']for n in nodes};by_id={n['id']:n for n in nodes};groups=defaultdict(list);unresolved=[];recursive=[]
for e in raw_edges:
 a,b=e.get('source'),e.get('target')
 if a not in node_ids or b not in node_ids:unresolved.append(e);continue
 if a==b:by_id[a].setdefault('recursive_relations',[]).append(e);recursive.append(e);continue
 groups[tuple(sorted((a,b)))].append(e)
edges=[]
for group in groups.values():
 e=dict(group[0]);e['relation']=' / '.join(sorted({v.get('relation','references')for v in group}));e['provenance']=group
 edges.append(e)
clean={'nodes':nodes,'edges':edges,'hyperedges':raw.get('hyperedges',[]),'input_tokens':0,'output_tokens':0}
(out/'.graphify_extract.json').write_text(json.dumps(clean,ensure_ascii=False),encoding='utf-8')
health=diagnose_extraction(clean,directed=False,root=str(root));print(format_diagnostic_report(health))
(out/'graph_health.json').write_text(json.dumps({'clean_graph':health,'raw_edges':len(raw_edges),'excluded_unresolved_endpoints':len(unresolved),'recursion_stored_as_node_attribute':len(recursive),'parallel_relations_preserved_in_provenance':len(raw_edges)-len(unresolved)-len(recursive)-len(edges)},indent=2),encoding='utf-8')
G=build_from_json(clean,root=str(root),directed=False)
if not G.number_of_nodes():raise SystemExit('Empty graph')
communities=cluster(G);cohesion=score_all(G,communities);labels={}
for cid,members in communities.items():
 ranked=sorted(members,key=lambda n:G.degree(n),reverse=True);top=[str(G.nodes[n].get('label',n)).replace('()','')for n in ranked[:2]]
 labels[cid]='Requisitos acadêmicos'if any(n.startswith('docs_requisitos_')for n in members)else ' / '.join(top)
gods=god_nodes(G);surprises=surprising_connections(G,communities);questions=suggest_questions(G,communities,labels)
files={'code':[str(f)for f in code],'paper':[str(source)],'document':[],'image':[],'video':[]}
detection={'files':files,'total_files':len(code)+1,'total_words':sum(len(f.read_text(encoding='utf-8').split())for f in code),'scan_root':str(root),'skipped_sensitive':[]}
if not to_json(G,communities,str(out/'graph.json'),force=True,community_labels=labels):raise SystemExit('Graph write failed')
report=generate(G,communities,cohesion,labels,gods,surprises,detection,{'input':0,'output':0},str(root),suggested_questions=questions)
report=report.replace('Token cost: 0 input · 0 output','Token cost: unavailable (delegation tool did not expose usage)')
report+=f'\n\n## Escopo e integridade\n\nExtração semântica: somente requisitos do sistema no PDF. Extração estrutural: src/ e web/. Sem MySQL. A visão simples agrega relações paralelas em provenance e registra recursão nos atributos dos nós. {len(unresolved)} relações com símbolos externos/não resolvidos foram excluídas da visualização; {len(recursive)} recursões foram mantidas nos atributos. A extração bruta completa está em extraction_raw.json. O diagnóstico do grafo exibido não contém endpoints ausentes, autorrelações ou colapsos sem proveniência.\n\nA ferramenta de delegação não informou o uso de tokens; zeros internos são marcadores indisponíveis e não representam custo zero.\n'
(out/'GRAPH_REPORT.md').write_text(report,encoding='utf-8')
(out/'.graphify_labels.json').write_text(json.dumps({str(k):v for k,v in labels.items()},ensure_ascii=False),encoding='utf-8')
(out/'.graphify_detect.json').write_text(json.dumps(detection),encoding='utf-8')
save_manifest(files,root=str(root),scan_corpus={f for values in files.values()for f in values})
print(f'Graph complete: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities')
