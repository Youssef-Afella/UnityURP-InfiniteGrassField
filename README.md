# UnityURP-InfiniteGrassField
An Infinite GPU Instanced Grass Field that doesn't require storing trillions of positions in memory

Preview Video : https://youtu.be/mj6hPL3cmfE

The idea is simple, we generate a uniform grid of points in an area and make it move with the camera<br/>
The trick is moving it in a way that doesn't let the player feel it moving<br/>
This is simply done by the famous steps formula "floor(value / step) * step"<br/>
In simple words, imagine having a grid that covering the whole space, and the points can only exist on this grid. So in order to follow the camera, we get the closest point to it in the grid and consider it the center of our square, and then we generate the other points around this point.<br/>

After this, we do a frustrum test to every point before adding it to the PositionsBuffer (I'm using and AppendStructuredBuffer)<br/>
Then we pass this buffer to the material, and inside of the material we add a small random offset (that is based on the world pos) to the position to give the grass some randomness<br/>

A visualisation for what we are doing:<br/>
![Movie_001](https://github.com/user-attachments/assets/5b0afd5d-c228-42a2-83d3-1c2600b65e64)<br/>
(The green dots are the points that we are going to test before adding them to the buffer)

This project is mostly based on this repo of Colin Leung:<br/>
https://github.com/ColinLeung-NiloCat/UnityURP-MobileDrawMeshInstancedIndirectExample
