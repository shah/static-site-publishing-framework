//+build mage

package main

import "context"
import "fmt"
import "github.com/magefile/mage/mg"
import "github.com/shurcooL/graphql"
import "encoding/json"

type Facets mg.Namespace

func (Facets) GenerateCatalog() {
	client := graphql.NewClient("https://graphql.medigy.com/graphql", nil)

	variables := map[string]interface{}{
		"tenantId":  graphql.String("7822da54-c0ba-11e8-85c1-6301a0c839d6"),
	}

	var query struct {
		AllFacets []struct {
			Nature graphql.String `graphql:"nature : category"`
			FacetNames []graphql.String `graphql:"facetNames : questionnaireName"`
		} `graphql:"allFacets : getCategoryListWithQuestionnaire(tenantId: $tenantId)"`
	}

	fmt.Printf("Running query %+v\n", query)
	if err := client.Query(context.Background(), &query, variables); err != nil {
		fmt.Println(err)
		return
	}

    JSON, err := json.MarshalIndent(query, "", "	")
    if err != nil {
		fmt.Println(err)
		return
    }
    fmt.Println(string(JSON))
}