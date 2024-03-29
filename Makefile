# Need on PATH
# og2dot: https://github.com/cmungall/obographviz
# dot: https://graphviz.org
# jq: https://stedolan.github.io/jq/
# curl

UBERGRAPH="https://ubergraph.apps.renci.org/sparql"

ROBOT = robot
NODE_ROOT = "UBERON_0002113"
PROPERTIES = "<http://purl.obolibrary.org/obo/BFO_0000050> <http://purl.obolibrary.org/obo/BFO_0000051>"
DEPTH = 3
SUBSET = Kidney_ASCTB_subset.json

all: renal-corpsule.png renal-corpsule.pdf

subset/$(SUBSET):
	curl https://raw.githubusercontent.com/hubmapconsortium/ccf-validation-tools/master/owl/$(SUBSET) > $@ 


sparql/%.rq:
	python generate_rq.py '{"node_root": $(NODE_ROOT), "properties": $(PROPERTIES), "depth": $(DEPTH)}' $@

%.result.json: sparql/%.rq
	 curl -X POST --data-binary @$< --header "Content-Type:application/sparql-query" --header "Accept:application/json" $(UBERGRAPH) >$@

%.obograph_p.json: %.result.json
	jq '.results | {graphs: [{ nodes: .bindings | map({id: .s.value, lbl: .slabel.value, type: "CLASS"}, {id: .p.value, lbl: .plabel.value, type: "PROPERTY"}, {id: .o.value, lbl: .olabel.value, type: "CLASS"}) | unique , edges: .bindings | map(. | { sub: .s.value, pred: .p.value, obj: .o.value }) } ]}' $< >$@

%.obograph.json: %.obograph_p.json subset/$(SUBSET)
	python merge_json.py $^ $@

dot/%.dot: %.obograph.json style/ubergraph-style.json
	og2dot.js -s style/ubergraph-style.json $< >$@

# .PRECIOUS: dot/%.dot

%.png: dot/%.dot
	dot $< -Tpng -Grankdir=LR >$@

%.pdf: dot/%.dot
	dot $< -Tpdf -Grankdir=LR >$@
