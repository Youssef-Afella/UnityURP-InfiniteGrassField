using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;

[ExecuteAlways]
public class InstancedIndirectGrassRenderer : MonoBehaviour
{
    [Header("Settings")]
    //We are simply generating a grid of points in a square that is centered in the camera positionXZ
    public int density = 500;
    //The density is actually the sqrt of the total count of points we are testing before passing them to the buffer
    //So the total number of points is density*density
    public float drawDistance = 150;
    //The drawDistance is the extent (half of the width) of our square
    //changing it won't affect the performance but the grass blades will be more spaced (You gonna have to increase the density value then)

    public Material instanceMaterial;

    [Header("Internal")]
    public ComputeShader computeShader;

    //=====================================================
    private Mesh cachedGrassMesh;

    private ComputeBuffer instancesPosWSBuffer;
    private ComputeBuffer argsBuffer;
    //=====================================================

    private int fps = 0;
    private int bufferLength = 0;
    private bool getPositionsBufferLength = false;

    private void Start()
    {
        StartCoroutine(FPSCounter());
    }

    void Update()
    {

        if (instancesPosWSBuffer != null)
            instancesPosWSBuffer.Release();

        if (argsBuffer != null)
            argsBuffer.Release();

        if (instanceMaterial == null || computeShader == null)
            return;

        //Initializing Buffers
        instancesPosWSBuffer = new ComputeBuffer(density * density, sizeof(float) * 3, ComputeBufferType.Append);

        uint[] args = new uint[5];
        args[0] = (uint)GetGrassMeshCache().GetIndexCount(0);
        args[1] = (uint)(density * density);
        args[2] = (uint)GetGrassMeshCache().GetIndexStart(0);
        args[3] = (uint)GetGrassMeshCache().GetBaseVertex(0);
        args[4] = 0;

        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        //Material Properties
        instanceMaterial.SetBuffer("_InstancesPosWSBuffer", instancesPosWSBuffer);
        instanceMaterial.SetFloat("_OffsetRange", drawDistance / density);

        //ComputeShader Properties
        Camera camera = Camera.main;
        computeShader.SetMatrix("_VPMatrix", camera.projectionMatrix * camera.worldToCameraMatrix);
        computeShader.SetFloat("_DrawDistance", drawDistance);
        computeShader.SetVector("_CameraPositionXZ", new Vector2(camera.transform.position.x, camera.transform.position.z));
        computeShader.SetInt("_CountSqrt", density);
        computeShader.SetBuffer(0, "_InstancesPosWSBuffer", instancesPosWSBuffer);

        //Reset Counter and Dispatching
        instancesPosWSBuffer.SetCounterValue(0);
        computeShader.Dispatch(0, Mathf.CeilToInt((float)density / 8), Mathf.CeilToInt((float)density / 8), 1);

        //After Dispatching is done we copy the count to the ArgsBuffer
        ComputeBuffer.CopyCount(instancesPosWSBuffer, argsBuffer, 4);

        //Getting data from GPU
        if (getPositionsBufferLength)
        {
            var countBuffer = new ComputeBuffer(1, 4, ComputeBufferType.Raw);
            var data = new uint[1];

            ComputeBuffer.CopyCount(instancesPosWSBuffer, countBuffer, 0);
            countBuffer.GetData(data);
            countBuffer.Release();

            bufferLength = (int)data[0];
        }
        else {
            bufferLength = 0;
        }

        //Rendering Bounds
        Bounds renderBound = new Bounds();
        renderBound.center = camera.transform.position;
        renderBound.extents = new Vector3(drawDistance, 0, drawDistance);

        //Big DrawCall
        Graphics.DrawMeshInstancedIndirect(GetGrassMeshCache(), 0, instanceMaterial, renderBound, argsBuffer);
    }

    IEnumerator FPSCounter()
    {

        while (true)
        {
            fps = (int)(1f / Time.unscaledDeltaTime);
            yield return new WaitForSeconds(0.1f);
        }
    }
    
    private void OnGUI()
    {
        GUI.contentColor = Color.black;

        GUIStyle style = new GUIStyle();
        style.fontSize = 25;

        GUIStyle style2 = new GUIStyle(GUI.skin.toggle);
        style2.fontSize = 25;

        GUI.Label(new Rect(50, 50, 400, 200),
            $"FPS : {fps}\n" +
            $"Total Dispatch Size : {density*density}\n",
            style);

        getPositionsBufferLength = GUI.Toggle(new Rect(50, 250, 400, 100), getPositionsBufferLength, "Get Positions Buffer Length", style2);

        string t1 = "Positions Buffer Length : " + (bufferLength == 0 ? "-" : "" + bufferLength);
        float memory = (bufferLength * 3 * 4) / 1048576.0f;
        string t2 = "Positions Buffer Estimated Memory : " + (bufferLength == 0 ? "-" : memory.ToString("0.00")) + "Mb";

        GUI.Label(new Rect(50, 350, 400, 200),
            t1+"\n" +
            t2+"\n",
            style);
        GUI.Label(new Rect(50, 410, 400, 200),
            "(Getting the buffer length require reading back\nthe data from the GPU so it will cause a\nperformance decrease, enable it for debugging only)",
            style);

        GUI.Label(new Rect(550, 50, 200, 30), "Density: " + density, style);
        density = Mathf.Max(1, (int)(GUI.HorizontalSlider(new Rect(550, 90, 200, 30), density / 200, 1, 10)) * 200);

        GUI.Label(new Rect(550, 120, 200, 30), "Draw Distance: " + drawDistance, style);
        drawDistance = Mathf.Max(1, (int)(GUI.HorizontalSlider(new Rect(550, 160, 200, 30), drawDistance / 60, 1, 10)) * 60);
    }
    
    void OnDisable()
    {
        if (instancesPosWSBuffer != null)
            instancesPosWSBuffer.Release();
        instancesPosWSBuffer = null;

        if (argsBuffer != null)
            argsBuffer.Release();
        argsBuffer = null;
    }

    //A simple triangle mesh
    Mesh GetGrassMeshCache()
    {
        if (!cachedGrassMesh)
        {
            cachedGrassMesh = new Mesh();

            Vector3[] verts = new Vector3[3];
            verts[0] = new Vector3(-0.25f, 0);
            verts[1] = new Vector3(+0.25f, 0);
            verts[2] = new Vector3(-0.0f, 1);

            int[] trinagles = new int[3] { 2, 1, 0, };

            cachedGrassMesh.SetVertices(verts);
            cachedGrassMesh.SetTriangles(trinagles, 0);
        }

        return cachedGrassMesh;
    }
}