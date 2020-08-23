# Dodging-Bird
This game is my version of the popular "Flappy Bird". Fly the bird through the pipes and watch as the background changes from day to night!
The pipes become harder to doge as the game speeds up gradually. Type "f" to make the bird flap up, and let gravity pull it back down. Try your best and see if you can become the next Dodging-Bird champion!

# Game Screen
See a demo here: https://youtu.be/DHhJsybnYe0

The game shifts from day to night as you progress: 


![Screen Shot 2020-08-23 at 1 14 59 AM](https://user-images.githubusercontent.com/56455442/90971427-20a86180-e4de-11ea-8233-3d583f9a178f.png)

![Screen Shot 2020-08-23 at 1 19 17 AM](https://user-images.githubusercontent.com/56455442/90971491-b3e19700-e4de-11ea-98e7-abbfe4e7e861.png)

![Screen Shot 2020-08-23 at 1 19 58 AM](https://user-images.githubusercontent.com/56455442/90971503-c8259400-e4de-11ea-9305-9d01f8120de6.png)

Game Over Screen:

![Screen Shot 2020-08-23 at 1 20 31 AM](https://user-images.githubusercontent.com/56455442/90971557-2ce0ee80-e4df-11ea-978a-69d0f64e3d28.png)




# How to Play the Game
You will need MARS 4.5 installed. To run the game, you need to go under "Tools" and select:
  - Keyboard and Display MMIO Simulator
  - Bitmap Display

*Bitmap Display Configuration:*
 - Unit width in pixels: 8					     
 - Unit height in pixels: 8
 - Display width in pixels: 256
 - Display height in pixels: 256
 - Base Address for Display: 0x10008000 ($gp)
 
 Be sure to click "Connect to MIPS" for both the bitmap display *and* the keyboard. 
 
