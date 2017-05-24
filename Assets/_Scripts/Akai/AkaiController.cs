using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
public class AkaiController : MonoBehaviour
{
    [SerializeField]
    float m_RunCycleLegOffset = 0.2f; //specific to the character

    private Animator m_animator;

    private Rigidbody m_rigidBody;

    private Vector2 m_move = Vector2.zero;

    private float m_forward, m_turn;

	// Use this for initialization
	void Start ()
    {
        m_animator = GetComponent<Animator>();
        if (m_animator == null)
        {
            Debug.Log("m_animator not found!");
        }

        m_rigidBody = GetComponent<Rigidbody>();
        if (m_rigidBody == null)
        {
            Debug.Log("m_rigidBody not found!");
        }
    }
	
	// Update is called once per frame
	void Update ()
    {
        UpdateAnimator();	
	}

    private void UpdateAnimator ()
    {
        //Debug.Log("m_forward == " + m_forward.ToString());
        m_animator.SetFloat("Forward", m_forward);
        m_animator.SetFloat("Turn", m_turn);

        float runCycle = Mathf.Repeat(m_animator.GetCurrentAnimatorStateInfo(0).normalizedTime + m_RunCycleLegOffset, 1);
        float jumpLeg = (runCycle < 0.5f ? 1 : -1) * m_forward;

        m_animator.SetFloat("JumpLeg", jumpLeg);
        
    }

    private void OnAnimatorMove()
    {
        Vector3 v = m_animator.deltaPosition / Time.deltaTime;

        // we preserve the existing y part of the current velocity.
        v.y = m_rigidBody.velocity.y;
        m_rigidBody.velocity = v;

        transform.Rotate(m_animator.deltaRotation.eulerAngles);
    }

    public void Move (Vector2 move, bool fast)
    {
        m_move = Vector2.Lerp(m_move, move, 10.0f * Time.deltaTime);

        m_forward = m_move.y;
        m_turn = m_move.x;
    }

    public void Jump ()
    {
        Debug.Log("jump!");
    }
}
