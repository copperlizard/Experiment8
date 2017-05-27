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

    private Vector3 m_groundOffset = Vector3.zero;

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

        m_groundOffset = m_cameraBoom.transform.position - m_akaiController.transform.position;

        m_cameraBoom.transform.parent = null; //free boom from local transforms
	}
	
	// Update is called once per frame
	void FixedUpdate ()
    {
        if (m_akaiController.IsGrounded())
        {            
            m_cameraBoom.transform.position = Vector3.Lerp(m_cameraBoom.transform.position, m_akaiController.GroundAt().point + m_groundOffset, 0.65f);            
            m_camera.transform.rotation = Quaternion.LookRotation((m_cameraBoom.transform.position - m_camera.transform.position).normalized);
            //m_cameraBoom.transform.position = m_akaiController.GroundAt().point + m_groundOffset;            
        }
        else
        {
            m_cameraBoom.transform.position = transform.position;
            m_camera.transform.rotation = Quaternion.LookRotation((transform.position - m_camera.transform.position).normalized);
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

            if (Vector3.Dot(m_cameraBoom.transform.forward, transform.forward) > 0.9999f)
            {
                m_autoRotate = false;
            }
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
            if (Vector3.Dot(m_cameraBoom.transform.forward, transform.forward) < 0.9999f)
            {
                m_autoRotate = true;
            }
        }

        yield return null;
        m_waitForInputDelay = false;
    }

    public void PanTilt (Vector2 move)
    {
        m_move = move;
    }

    public Transform GetBoom ()
    {
        return m_cameraBoom;
    }
}
