# TODO

[ ] Paths
## 2024-03-03

[ ] Render Character on Screen
[ ] Get Character Grid Movement Going (Mouse and Click)
[ ] Build Map
[ ] Generate Dungeon
[ ] Add Enemies
[ ] Combat


### Nice to Haves

[ ] Toast whenever there is a message
[ ] A logging system

## THOUGHTS

Essentially thoughts I have when developing, so I can re-read this and remind
myself of my decisions. Basically my personal Architect of Record

### Thought List

- I need to have multiple AStar finders, because I will need to have path finds that care about entities,
and some about theres.
- We're just gong to build out a movement grid around any specific character,
pass that into the WorldPathfinder to decide if we move there.
The movement Grid will have meta data such as difficult of travel and such.
