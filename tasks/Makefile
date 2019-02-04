#
# Static Site Publishing Framework (SSPF) Tasks Makefile

SHELL := /bin/bash
MAKEFLAGS := silent

GRAPHQL_ENDPOINT ?= https://graphql.medigy.com/graphql

define FACETS_CATALOG_GRAPHQL
query facetsQuery($$tenantId : String!) { 
	allFacets : getCategoryListWithQuestionnaire(tenantId: $$tenantId) {
		nature : category
		facets : questionnaireName
	}
}
endef

define FACET_INSTANCE_GRAPHQL
query facetQuery($$tenantId : String!, $$facet: String!, $$nature : String!) { 
  facet : getQuestionnaire(name: $$facet, category: $$nature, tenantId: $$tenantId) {
    lformsJsonAsText : instance
  }
}
endef

export FACETS_CATALOG_GRAPHQL
facets-catalog.json:
	@echo "$$FACETS_CATALOG_GRAPHQL" | \
		jq -Rsn '(inputs) as $$src | { "query" : "\($$src)", "variables" : { "tenantId" : "7822da54-c0ba-11e8-85c1-6301a0c839d6"} }' | \
		curl -H "Content-Type: application/json" -X POST -d @- $(GRAPHQL_ENDPOINT) | \
		jq '.data.allFacets | map( { (.nature|tostring): { slug: (.nature|ascii_downcase|gsub("[\\s\\-_]+";"-")), facets : .facets | map( { (.|tostring): { slug: (.|ascii_downcase|gsub("[\\s\\-_]+";"-")), name : ., lform: "{  }" } } ) | add } } ) | add' > $@

ONESHELL:
facets-catalog.csv: facets-catalog.json
	cat facets-catalog.json | \
		jq -r 'keys[] as $$nature | .[$$nature].facets | keys[] as $$facet | "\"\($$nature)\",\"\($$facet),\(.[$$facet].slug).json\""'

export FACET_INSTANCE_GRAPHQL
facet-instance.json:
	@echo "$$FACET_INSTANCE_GRAPHQL" | \
		jq -Rsn '(inputs) as $$src | { "query" : "\($$src)", "variables" : { "nature": "Ethics and Compliance", "facet": "CARIN Alliance Code of Conduct", "tenantId" : "7822da54-c0ba-11e8-85c1-6301a0c839d6"} }' | \
		curl -H "Content-Type: application/json" -X POST -d @- $(GRAPHQL_ENDPOINT) | \
		jq '.data.facet.lformsJsonAsText | fromjson ' > $@

all: facets-catalog.json facet-instance.json

clean:
	rm -f facets-catalog.json
	rm -f facet-instance.json
