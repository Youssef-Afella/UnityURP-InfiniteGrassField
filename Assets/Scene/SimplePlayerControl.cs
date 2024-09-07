using UnityEngine;

public class SimplePlayerControl : MonoBehaviour
{
    public float speed = 15;
    public float rotateSpeed = 120;

    // Update is called once per frame
    void Update()
    {
        // Move
        var forward = transform.forward * Input.GetAxis("Vertical");
        var side = transform.right * Input.GetAxis("Horizontal");
        transform.position = transform.position + speed * Time.deltaTime * (side + forward).normalized;

        // Rotate
        var rotation = 0f;
        rotation += Input.GetKey(KeyCode.Q) ? -1 : 0;
        rotation += Input.GetKey(KeyCode.E) ? 1 : 0;
        transform.Rotate(Vector3.up, rotation * rotateSpeed * Time.deltaTime);
    }
}
