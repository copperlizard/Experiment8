using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AkaiCameraRigController : MonoBehaviour
{
    [SerializeField]
    private float m_autoRotateInputDelay = 2.0f;

    private AkaiController m_akaiController;

    private Camera m_camera;

    private Transform m_cameraBoom;

    private Vector2 m_move = Vector2.zero;

    private bool m_autoRotate = false, m_waitForInputDelay = false;

	// Use this for initialization
	void Start ()
    {
        m_akaiController = GetComponentInParent<AkaiController>();
        {
            if (m_akaiController == null)
            {
                Debug.Log("m_akaiController not found!");
            }
        }

        m_cameraBoom = transform.GetChild(0);
        if (m_cameraBoom == null)
        {
            Debug.Log("m_cameraBoom not found!");
        }
        else
        {
            m_camera = m_cameraBoom.GetComponentInChildren<Camera>();
            if (m_camera == null)
            {
                Debug.Log("m_camera not found!");
            }
        }

        m_cameraBoom.transform.parent = null; //free boom from local transforms
	}
	
	// Update is called once per frame
	void Update ()
    {
        float ydif = m_cameraBoom.transform.position.y - transform.position.y;
        if (ydif < 0.0f)
        {
            ydif = -ydif;
        }

        if (m_akaiController.IsGrounded())
        {
            if (ydif > 0.10f)
            {
                m_cameraBoom.transform.position = new Vector3(transform.position.x, Mathf.Lerp(m_cameraBoom.transform.position.y, transform.position.y, ydif / 0.5f), transform.position.z);
            }
            else
            {
                m_cameraBoom.transform.position = new Vector3(transform.position.x, m_cameraBoom.position.y, transform.position.z);
            }
        }
        else
        {
            m_cameraBoom.transform.position = transform.position;
        }        

        if (m_move.magnitude <= 0.001f && !m_waitForInputDelay)
        {
            StartCoroutine(WaitForInputDelay());
        }
        else if (m_move.magnitude > 0.001f)
        {
            m_autoRotate = false;
        }

        if (m_autoRotate)
        {
            m_cameraBoom.transform.rotation = Quaternion.RotateTowards(m_cameraBoom.transform.rotation, transform.rotation, 1.25f);
        }
    }

    private IEnumerator WaitForInputDelay ()
    {
        m_waitForInputDelay = true;

        float startTime = Time.time;
        
        while (startTime + m_autoRotateInputDelay > Time.time && m_move.magnitude <= 0.001f)
        {
            yield return null;
        }

        if (m_move.magnitude <= 0.001f)
        {
            m_autoRotate = true;
        }

        yield return null;
        m_waitForInputDelay = false;
    }

    public void PanTilt (Vector2 move)
    {
        m_move = move;
    }
}
