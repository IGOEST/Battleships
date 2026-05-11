# Battleships

## Game description 

Battleships is a game meant to be played by two players.

### Starting game: 

At the beginning, player types in the username they want to be identified with. 

<img width="1152" height="699" alt="Image" src="https://github.com/user-attachments/assets/c50fefd2-4f95-447d-8971-01c2b02e4b53" />

Then, they need to place all their ships, listed on the right side of the screen. Ships can be placed horizontally or vertically – to change between those options, players can choose ‘rotate ship’. Ship cannot be placed on any of the fields neighboring other, already placed ship. If player is not satisfied with their ship placement, they can clear the board and start again. 

<img width="1153" height="695" alt="Image" src="https://github.com/user-attachments/assets/79f4eeb1-b226-45a4-a4a5-d115295fddb4" />

Once all ships have been placed, players can start the game. 

<img width="1151" height="700" alt="Image" src="https://github.com/user-attachments/assets/c112cb21-f582-4efc-9a16-b7b2d10b041e" />

The game will not start until both players are ready. If only one player is ready, they will be forced to wait for the second player. 

<img width="1170" height="638" alt="Image" src="https://github.com/user-attachments/assets/44ef9d9a-a357-405e-b12f-5633011e3fb1" />

### Gameplay: 

Players are making their moves in turns. Player chooses one field to shoot at – it cannot be a field that they shot at before. Once they shoot, the result can be miss, if they did not shoot any ship, hit if they shoot ship and sunk if they shoot ship and all fields that ship is placed on had been shot. 

<img width="1155" height="695" alt="Image" src="https://github.com/user-attachments/assets/660185fd-80a4-4786-9312-2e8de5f003dc" />

Once one player sinks all the ships of their opponent, they win and the game ends. 

<img width="1151" height="697" alt="Image" src="https://github.com/user-attachments/assets/82fe370a-45b5-4719-96d1-fdae04079ee6" />

<img width="1090" height="622" alt="Image" src="https://github.com/user-attachments/assets/72284844-915e-4c5c-ba18-3b1a5c63cee9" />

### Conection issues:

Game cannot continue if one player disconnects, or server fails. 

<img width="1155" height="692" alt="Image" src="https://github.com/user-attachments/assets/b05db9fe-dd29-4794-a713-e9ac00a57f65" />

<img width="1153" height="691" alt="Image" src="https://github.com/user-attachments/assets/da61fc81-4e17-428f-9f1f-eda7710a8807" />

## Project’s file structure 

Our project is divided into 2 folders: 

1. server - containing files connected with game logic, saving any necessary variables (such as players’ boards) and sending/receiving messages from the server side 

    * scripts: game_logic, messagePacket, server 

2. client – containing files connected with managing UI and sending/receiving messages from the client side, as well as UI visual attributes for the game 

    * scripts: client, game_manager, grid_square, messagePacket 

To successfully run the game, there needs to be one instance of server, and two instances of client started. 

## Technology used 

The project is developed in Godot 4 Engine, using its built-in GDScript language to handle game logic and user interface, without the need for external frameworks or libraries. All graphical elements and interactions are managed through Godot’s system, that is based on nodes and connecting them with code by signals.

## Contribution of individual group members: 

### Igor Estrop - implementing server-client communication and implementing game logic. 

Specific assigned tasks: 

  * Creating server with main thread that creates sockets and establishes connections with clients, creating client threads for each client.  

  * Create communication for game logic thread and client threads 

  * Create game logic in the game logic thread 

### Hanna Burdziej - handling communication between threads and message building logic. 

Specific assigned tasks: 

  * Designing and creating message packets, types, and what is in them. Creating functions to transform packets into messages and back. 

  * Creating client thread logic to handle receiving and sending messages to clients. 

  * Creating network thread with receiving messages 

  * Creating UI/input thread with sending messages 

  * Creating queue that is a shared resource between network and UI/input threads and implementing how they access it, what is put in there 

 

### Aleksandra Templin - handling UI and logic (based on messages) for game initiation and players creating board 

Specific assigned tasks: 

  * Create logic for creating board (putting ships in places) 

  * Create UI for game initiation – creating initial screen that user sees (welcome to the game, type your username, waiting for another player to join), putting ships in places 

  * Create game view and way of getting user input from it, communicating input to the server 

  * Handle making changes to board based on messages in UI/input thread 
    
