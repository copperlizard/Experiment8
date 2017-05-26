using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(AkaiCameraRigController))]
public class AkaiCameraRigControllerInput : MonoBehaviour
{
    private Vector2 m_move = Vector2.zero;

    private AkaiCameraRigController m_rigController;

	// Use this for initialization
	void Start ()
    {
        m_rigController = GetComponent<AkaiCameraRigController>();
        if (m_rigController == null)
        {
            Debug.Log("m_rigController not found!");
        }
	}
	
	// Update is called once per frame
	void Update ()
    {
        GetInput();
    }

    private void GetInput()
    {
        //Add control options here

        GetXBOXcontrollerInput();

        m_rigController.PanTilt(m_move);
    }

    private void GetXBOXcontrollerInput()
    {
        m_move.x = Input.GetAxis("axis4");
        m_move.y = -Input.GetAxis("axis5");
                
        //Debug.Log("m_move == " + m_move.ToString());
    }
}
