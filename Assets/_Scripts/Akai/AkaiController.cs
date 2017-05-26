using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
public class AkaiController : MonoBehaviour
{
    [SerializeField]
    float m_StationaryTurnSpeed = 180.0f, m_MovingTurnSpeed = 360.0f, m_RunCycleLegOffset = 0.2f; //specific to the character

    private Animator m_animator;

    private Rigidbody m_rigidBody;

    private RaycastHit m_groundAt;

    private Vector2 m_move = Vector2.zero;

    private float m_forward, m_turn;

    private bool m_grounded = true;

    // Use this for initialization
    void Start()
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
    void Update()
    {
        UpdateAnimator();
    }

    private void UpdateAnimator()
    {
        //Debug.Log("m_forward == " + m_forward.ToString());
        m_animator.SetFloat("Forward", m_forward);
        m_animator.SetFloat("Turn", m_turn);

        float runCycle = Mathf.Repeat(m_animator.GetCurrentAnimatorStateInfo(0).normalizedTime + m_RunCycleLegOffset, 1);
        float jumpLeg = (runCycle < 0.5f ? 1 : -1) * m_forward;

        m_animator.SetFloat("JumpLeg", jumpLeg);

    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(m_groundAt.point, 0.05f);
    }

    private void OnAnimatorMove()
    {
        Vector3 v = m_animator.deltaPosition / Time.deltaTime;

        if (!m_grounded)
        {
            // preserve the existing y part of the current velocity.
            v.y = m_rigidBody.velocity.y;
        }

        m_rigidBody.velocity = v;

        //transform.Rotate(m_animator.deltaRotation.eulerAngles);
    }

    #region MovementFunctions

    void ApplyRotation()
    {
        // In addition to root rotation in the animation
        float turnSpeed = Mathf.Lerp(m_StationaryTurnSpeed, m_MovingTurnSpeed, m_forward);
        transform.Rotate(0, m_turn * turnSpeed * Time.deltaTime, 0);
    }

    private void GroundCheck()
    {
        Vector3 kneeHeightPos = transform.position + transform.up * 0.5f; //0.5f being ~character_height - capsule_height

        if (Physics.Raycast(kneeHeightPos, -transform.up, out m_groundAt, 1.0f, ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            float inclineCheck = Vector3.Dot(m_groundAt.normal, Vector3.up);

            if (inclineCheck >= 0.5f)
            {
                m_grounded = true;
                m_rigidBody.useGravity = false;

                float curY = transform.position.y, groundY = m_groundAt.point.y;
                float setY = Mathf.Lerp(curY, groundY, 10.0f * Time.deltaTime);
                transform.position = new Vector3(transform.position.x, setY, transform.position.z);

                return;
            }
        }

        m_grounded = false;
        m_rigidBody.useGravity = true;
    }

    public void Move(Vector2 move, bool fast)
    {
        m_move = Vector2.Lerp(m_move, move, 10.0f * Time.deltaTime);

        m_forward = m_move.y;
        m_turn = m_move.x;

        ApplyRotation();
        GroundCheck();
    }

    public void Jump()
    {
        Debug.Log("jump!");
    }
    #endregion

    #region SetGetStatusFunctions

    public bool IsGrounded()
    {
        return m_grounded;
    }

    #endregion


}
