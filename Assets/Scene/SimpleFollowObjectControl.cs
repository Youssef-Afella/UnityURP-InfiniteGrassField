using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleFollowObjectControl : MonoBehaviour
{
    public Transform target;
    private Vector3 velocity;

    Vector3 targetOffset;
    private void Start()
    {
        targetOffset = transform.position - target.position;
    }

    void Update()
    {
        transform.position = Vector3.SmoothDamp(transform.position, target.position + targetOffset, ref velocity, 0.2f);
    }
}
