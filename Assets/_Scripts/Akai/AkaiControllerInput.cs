using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(AkaiController))]
public class AkaiControllerInput : MonoBehaviour
{
    [SerializeField]
    private float m_jumpOrFastTime = 0.2f;

    private AkaiController m_akaiController;

    private Vector2 m_move = Vector2.zero;
    
    private bool m_fast = false, m_fastCheck = false, m_crouch = false;

    // Use this for initialization
    void Start()
    {
        m_akaiController = GetComponent<AkaiController>();
        if (m_akaiController == null)
        {
            Debug.Log("m_akaiController not found!");
        }
    }

    // Update is called once per frame
    void Update()
    {
        GetInput();
    }

    private void GetInput()
    {
        //Add control options here

        GetXBOXcontrollerInput();
        
        m_akaiController.Move(m_move, m_fast);
    }

    private void GetXBOXcontrollerInput()
    {
        m_move.x = Input.GetAxis("Xaxis");
        m_move.y = -Input.GetAxis("Yaxis");

        //Debug.Log("Input.GetAxis(Yaxis) == " + Input.GetAxis("Yaxis").ToString());

        //Debug.Log("m_move == " + m_move.ToString());

        if (!m_fastCheck && Input.GetButton("button0"))
        {
            StartCoroutine(JumpOrFast());
        }

        m_akaiController.Crouch((Input.GetAxis("axis10") >= 0.5f));
        
    }

    private IEnumerator JumpOrFast()
    {
        m_fastCheck = true;

        float endTime = Time.time + m_jumpOrFastTime;
        while (Input.GetButton("button0") && endTime > Time.time)
        {
            yield return null;
        }

        if (Input.GetButton("button0"))
        {
            m_fast = true;

            while (Input.GetButton("button0"))
            {
                yield return null;
            }

            m_fast = false;
        }
        else
        {
            m_akaiController.Jump();
        }

        m_fastCheck = false;
        yield return null;
    }
}
