# TODO

[ ] Create a System to display the current proposed action
[ ] Disable the In-accessible actions
[ ] Add a Next Turn Button

## 2024-03-03

[x] Render Character on Screen
[x] Get Character Grid Movement Going (Mouse and Click)
[x] Add Enemies
[-] Combat
[ ] Build Map
[ ] Generate Dungeon

## Combat

[x] Turns
[ ] Actions

### Nice to Haves

[ ] Toast whenever there is a message
[ ] A logging system
[ ] Panning with both mouse and the keyboard
[ ] Black outline around mouse
[ ] Mouse hover rotates the card
[ ] Display the Traits for Actions
[ ] Only use the White atlas, and pick the colors from the pallete
[ ] Origin can be an enum or a position
[ ] Display Hands for the Selected Items
[ ] Display a Portait for Selected
[ ] I think I need an action system that stories itself in a DataPool, so I can have
multi-frame actions
[ ] Allow Custom Paths, and Movement Undo (Unless a Roll has Happened)

## Actions GUI
[ ] Do a Scissoring on the Cards
[ ] Allow Actions to be Scroll
[ ] Have a Deck to Search for Actions
[ ] Allow Text Search for Action (Steam Deck)

### Problems to Check for

[ ] Ring Buffer had a bug when it became full. I need to check into this more

## THOUGHTS

Essentially thoughts I have when developing, so I can re-read this and remind
myself of my decisions. Basically my personal Architect of Record

### Thought List

- I need to have multiple AStar finders, because I will need to have path finds that care about entities,
and some about theres.
- We're just gong to build out a movement grid around any specific character,
pass that into the WorldPathfinder to decide if we move there.
The movement Grid will have meta data such as difficult of travel and such.
