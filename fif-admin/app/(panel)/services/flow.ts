/**
 * The shape of a question flow, and how to measure one.
 *
 * Neither server nor client: the page counts a tree while rendering on the
 * server, and the editor counts the same tree as someone types. Exporting it
 * from the `'use client'` editor made the page import a client function, which
 * Next refuses at request time — a `'use client'` boundary is about where code
 * RUNS, and a plain function has no business declaring one.
 */

export type FlowNode = {
  id?: string
  name?: string
  icon?: string
  description?: string
  urgent?: boolean
  requiresDescription?: boolean
  options?: FlowNode[]
}

export function countTree(categories: FlowNode[]): { categories: number; options: number } {
  let options = 0
  const walk = (nodes: FlowNode[]) =>
    nodes.forEach((n) => {
      options++
      if (n.options) walk(n.options)
    })
  categories.forEach((c) => walk(c.options ?? []))
  return { categories: categories.length, options }
}
