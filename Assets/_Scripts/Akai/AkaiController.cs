using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
public class AkaiController : MonoBehaviour
{
    [SerializeField]
    float m_StationaryTurnSpeed = 180.0f, m_MovingTurnSpeed = 360.0f, m_RunCycleLegOffset = 0.2f; 

    private AkaiCameraRigController m_cameraRig;
    private Transform m_cameraBoom;
    private Camera m_camera;

    private Animator m_animator;

    private Rigidbody m_rigidBody;

    private RaycastHit m_groundAt;

    private Quaternion m_QuickTurnStartRot;

    private Vector2 m_move = Vector2.zero;

    private float m_forward, m_turn, m_forwardIncline, m_lookWeight = 1.0f;

    private bool m_grounded = true, m_jumping = false, m_quickTurning = false, m_headLook = true;

    #region UnityEventFuntions

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
        else
        {
            m_rigidBody.freezeRotation = true;
        }

        m_cameraRig = GetComponentInChildren<AkaiCameraRigController>();
        if (m_cameraRig == null)
        {
            Debug.Log("m_cameraRig not found!");
        }
        else
        {
            m_cameraBoom = m_cameraRig.GetBoom();
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
        }
    }

    // Update is called once per frame
    void Update ()
    {        
        UpdateAnimator();
    }

    private void FixedUpdate ()
    {
        GroundCheck();
    }

    private void UpdateAnimator()
    {
        //Debug.Log("m_forward == " + m_forward.ToString());
        m_animator.SetFloat("Forward", m_forward);
        m_animator.SetFloat("Turn", m_turn);
        m_animator.SetFloat("ForwardIncline", m_forwardIncline);
        
        float runCycle = Mathf.Repeat(m_animator.GetCurrentAnimatorStateInfo(0).normalizedTime + m_RunCycleLegOffset, 1);
        float jumpLeg = (runCycle < 0.5f ? 1 : -1) * m_forward;
        m_animator.SetFloat("JumpLeg", jumpLeg);


        m_animator.SetBool("Grounded", m_grounded);
        m_animator.SetBool("Jumping", m_jumping);
    }

    private void OnAnimatorMove()
    {
        if (Time.timeScale <= 0.0f)
        {
            return;
        }

        Vector3 v = m_animator.deltaPosition / Time.deltaTime;

        if (!m_grounded)
        {
            // preserve the existing y part of the current velocity.
            //v.y = m_rigidBody.velocity.y;
            v = m_rigidBody.velocity;
        }

        m_rigidBody.velocity = Vector3.Lerp(m_rigidBody.velocity, v, 8.0f * Time.deltaTime);        
    }

    private void OnAnimatorIK(int layerIndex)
    {
        m_lookWeight = (m_headLook) ? Mathf.Lerp(m_lookWeight, 1.0f, 3.0f * Time.deltaTime) : Mathf.Lerp(m_lookWeight, 0.0f, 30.0f * Time.deltaTime);
        m_animator.SetLookAtWeight(m_lookWeight);
        m_animator.SetLookAtPosition(m_cameraBoom.transform.position + m_cameraBoom.transform.forward * 10.0f);
    }

    /*private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            transform.position = transform.position + collision.contacts[0].normal * 0.1f;
        }
    }*/

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(m_groundAt.point, 0.05f);
    }

    #endregion

    #region MovementFunctions

    private void ApplyRotation ()
    {
        // In addition to root rotation in the animation
        float turnSpeed = Mathf.Lerp(m_StationaryTurnSpeed, m_MovingTurnSpeed / Mathf.Max(1.0f, m_forward), m_forward);
        transform.Rotate(0, m_turn * turnSpeed * Time.deltaTime, 0);
    }

    private void QuickTurn ()
    {
        if (!m_quickTurning)
        {
            Vector3 move3d = new Vector3(m_move.x, 0.0f, m_move.y);
            move3d = transform.TransformDirection(move3d);
            Quaternion tarRot = Quaternion.LookRotation(move3d, Vector3.up);

            StartCoroutine(QuickTurning(transform.rotation, tarRot));
        }
    }

    private IEnumerator QuickTurning (Quaternion startRot, Quaternion tarRot)
    {
        m_quickTurning = true;
        m_headLook = false;

        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);

        float ang = Quaternion.Angle(startRot, tarRot);        
        if (animState.IsName("QuickTurnAroundRightFoot"))
        {
            ang = ang - 360.0f;
        }

        while (animState.normalizedTime < 1.0f && (animState.IsName("QuickTurnAroundLeftFoot") || animState.IsName("QuickTurnAroundRightFoot")))
        {   
            transform.rotation = startRot * Quaternion.Euler(0.0f, -ang * Mathf.SmoothStep(0.0f, 1.0f, animState.normalizedTime), 0.0f);

            animState = m_animator.GetCurrentAnimatorStateInfo(0);
            yield return null;
        }

        transform.rotation = tarRot;

        m_quickTurning = false;
        m_headLook = true;
        yield return null;
    }

    private void GroundCheck ()
    {
        if (m_jumping)
        {
            return;
        }

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

                Vector3 projNorm = Vector3.ProjectOnPlane(m_groundAt.normal, transform.right).normalized;
                
                m_forwardIncline = Mathf.Lerp(m_forwardIncline, -Vector3.Dot(projNorm, transform.forward), 5.0f * Time.deltaTime);

                return;
            }
        }

        m_grounded = false;
        m_rigidBody.useGravity = true;
    }

    public void Move (Vector2 move, bool fast)
    {
        if (fast)
        {
            move *= 2.0f;
        }
        
        //Rotate move relative to camera rig
        Vector3 move3d = new Vector3(move.x, 0.0f, move.y);

        //Vector3 camForward = Vector3.ProjectOnPlane(m_camera.transform.forward, Vector3.up).normalized;
        //Quaternion rot = Quaternion.FromToRotation(transform.forward, camForward);
        //Quaternion rot = Quaternion.FromToRotation(Vector3.ProjectOnPlane(transform.forward, Vector3.up).normalized, camForward);

        Quaternion rot = Quaternion.Euler(0.0f, m_camera.transform.rotation.eulerAngles.y - transform.rotation.eulerAngles.y, 0.0f);

        //Debug.Log("\nmove3d.magnitude before rotation == " + move3d.magnitude.ToString());
        //Debug.Log("\nmove3d before rotation == " + move3d.ToString());
        move3d = rot * move3d;
        //Debug.Log("move3d.magnitude after rotation == " + move3d.magnitude.ToString());
        //Debug.Log("\nmove3d after rotation == " + move3d.ToString());

        /*if (move3d.y > 0.0f)
        {
            Debug.Log("move3d.y == " + move3d.y.ToString());
            Time.timeScale = 0.0f;
        }*/

        move.x = move3d.x;
        move.y = move3d.z;
      
        m_move = Vector2.Lerp(m_move, move, 10.0f * Time.deltaTime);

        //Debug.Log("m_move == " + m_move.ToString());

        m_forward = m_move.y;
        m_turn = m_move.x;
        
        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);
        if (animState.IsName("Normal Locomotion Blend Tree") && !m_quickTurning)
        {
            ApplyRotation();
        }
        else if (animState.IsName("QuickTurnAroundLeftFoot") || animState.IsName("QuickTurnAroundRightFoot"))
        {
            QuickTurn();            
        }
    }

    public void Jump ()
    {
        if (m_jumping)
        {
            return;
        }

        StartCoroutine(Jumping());
    }

    private IEnumerator Jumping ()
    {
        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);

        Debug.Log("jump!");
        m_jumping = true;
        m_grounded = false;
        m_rigidBody.useGravity = true;


        while (!animState.IsName("Left Leg Jump Blend Tree") && !animState.IsName("Right Leg Jump Blend Tree"))
        {
            yield return null;
        }

        while (animState.IsName("Left Leg Jump Blend Tree") || animState.IsName("Right Leg Jump Blend Tree"))
        {   
            yield return null;
        }
                
        m_jumping = false;

        yield return null;
    }

    #endregion

    #region SetGetStatusFunctions

    public bool IsGrounded ()
    {
        return m_grounded;
    }

    public RaycastHit GroundAt ()
    {
        return m_groundAt;
    }

    #endregion
}
