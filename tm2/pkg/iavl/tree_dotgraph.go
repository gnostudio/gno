package iavl

import (
	"bytes"
	"fmt"
	"io"
	"maps"
	"text/template"
)

type graphEdge struct {
	From, To string
}

type graphNode struct {
	Hash  string
	Label string
	Value string
	Attrs map[string]string
}

type graphContext struct {
	Edges []*graphEdge
	Nodes []*graphNode
}

var graphTemplate = `
strict graph {
	{{- range $i, $edge := $.Edges}}
	"{{ $edge.From }}" -- "{{ $edge.To }}";
	{{- end}}

	{{range $i, $node := $.Nodes}}
	"{{ $node.Hash }}" [label=<{{ $node.Label }}>,{{ range $k, $v := $node.Attrs }}{{ $k }}={{ $v }},{{end}}];
	{{- end}}
}
`

var tpl = template.Must(template.New("iavl").Parse(graphTemplate))

var defaultGraphNodeAttrs = map[string]string{
	"shape": "circle",
}

func WriteDOTGraph(w io.Writer, tree *ImmutableTree, paths []PathToLeaf) {
	ctx := &graphContext{}

	tree.root.hashWithCount()
	tree.root.traverse(tree, true, func(node *Node) bool {
		graphNode := &graphNode{
			Attrs: map[string]string{},
			Hash:  fmt.Sprintf("%x", node.hash),
		}
		maps.Copy(graphNode.Attrs, defaultGraphNodeAttrs)
		shortHash := graphNode.Hash[:7]

		graphNode.Label = mkLabel(fmt.Sprintf("%s", node.key), 16, "sans-serif")
		graphNode.Label += mkLabel(shortHash, 10, "monospace")
		graphNode.Label += mkLabel(fmt.Sprintf("version=%d", node.version), 10, "monospace")

		if node.value != nil {
			graphNode.Label += mkLabel(string(node.value), 10, "sans-serif")
		}

		if node.height == 0 {
			graphNode.Attrs["fillcolor"] = "lightgrey"
			graphNode.Attrs["style"] = "filled"
		}

		for _, path := range paths {
			for _, n := range path {
				if bytes.Equal(n.Left, node.hash) || bytes.Equal(n.Right, node.hash) {
					graphNode.Attrs["peripheries"] = "2"
					graphNode.Attrs["style"] = "filled"
					graphNode.Attrs["fillcolor"] = "lightblue"
					break
				}
			}
		}
		ctx.Nodes = append(ctx.Nodes, graphNode)

		if node.leftNode != nil {
			ctx.Edges = append(ctx.Edges, &graphEdge{
				From: graphNode.Hash,
				To:   fmt.Sprintf("%x", node.leftNode.hash),
			})
		}
		if node.rightNode != nil {
			ctx.Edges = append(ctx.Edges, &graphEdge{
				From: graphNode.Hash,
				To:   fmt.Sprintf("%x", node.rightNode.hash),
			})
		}
		return false
	})

	if err := tpl.Execute(w, ctx); err != nil {
		panic(err)
	}
}

func mkLabel(label string, pt int, face string) string {
	return fmt.Sprintf("<font face='%s' point-size='%d'>%s</font><br />", face, pt, label)
}
