"""
    AbstractMTGNode

Interface for MTG node handles backed by a user-owned topology or attribute store.
The ordinary [`Node`](@ref) remains the default implementation.

A backend implements `node_id`, `node_mtg`, `node_attributes`, `Base.parent` and
`AbstractTrees.children`. The child collection must support indexed iteration and
contain handles of a compatible concrete type. Node identity must remain stable
while its storage moves; access to a removed handle must fail explicitly.

The interface supplies encoding accessors, attribute indexing, preorder traversal,
root and ID lookup. Mutation is opt-in: implement [`add_node!`](@ref), `reparent!`,
`delete_node!` and `prune!` as needed. Export and all specialized columnar APIs are
not automatically provided for a custom backend.
"""
abstract type AbstractMTGNode end
