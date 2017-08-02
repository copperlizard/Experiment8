using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BasicRotator : MonoBehaviour
{
    [SerializeField]
    private Vector3 rot = new Vector3(5.0f, 15.7f, 33.5f);

	// Use this for initialization
	void Start ()
    {
		
	}
	
	// Update is called once per frame
	void Update ()
    {
        transform.Rotate(rot * Time.deltaTime);
	}
}
