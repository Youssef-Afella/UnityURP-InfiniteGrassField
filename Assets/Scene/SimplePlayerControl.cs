using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimplePlayerControl : MonoBehaviour
{
    public float speed = 1;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 dir = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));
        transform.Translate(dir * speed);
    }
}
