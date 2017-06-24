﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(Rigidbody))]
public class AkaiController : MonoBehaviour
{
    [SerializeField]
    float m_StationaryTurnSpeed = 180.0f, m_MovingTurnSpeed = 360.0f, m_RunCycleLegOffset = 0.2f, m_jumpCoolDown = 0.2f, m_characterHeight = 1.8f; 

    private AkaiCameraRigController m_cameraRig;
    private Transform m_cameraBoom;
    private Camera m_camera;

    private Animator m_animator;

    private AkaiFootFallIK m_footFallIK;

    private Rigidbody m_rigidBody;
    private CapsuleCollider m_characterCollider;

    private RaycastHit m_groundAt, m_leftHandLedgeGrab, m_rightHandLedgeGrab; //handgrabs for logic not anim.IK

    //private Quaternion m_QuickTurnStartRot;

    private ContactPoint m_levelContactPointA = new ContactPoint(), m_levelContactPointB = new ContactPoint(); //NEED TO STOP USING CONTACT POINTS!!!

    private Vector2 m_move = Vector2.zero;

    private float m_forward, m_turn, m_forwardIncline, m_jumpLeg = 0.0f, m_lookWeight = 1.0f, m_sink, m_facingWall;

    private bool m_grounded = true, m_jumping = false, m_jumpOnCD = false, m_crouching = false, m_quickTurn = false, m_quickTurning = false, m_headLook = true, m_facingDirection = false,
        m_touchingLevel = false, m_leftHandHoldFound = false, m_rightHandHoldFound = false, m_ledgeGrab = false, m_ledgeClimb = false, m_ledgeClimbing = false, 
        m_wallRun = false, m_wallClimb = false, m_groundReset = false;

    #region UnityEventFuntions

    // Use this for initialization
    void Start()
    {
        m_animator = GetComponent<Animator>();
        if (m_animator == null)
        {
            Debug.Log("m_animator not found!");
        }

        m_footFallIK = GetComponent<AkaiFootFallIK>();
        if (m_footFallIK == null)
        {
            Debug.Log("m_footFallIK not found!");
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

        m_characterCollider = GetComponent<CapsuleCollider>();
        if (m_characterCollider == null)
        {
            Debug.Log("m_characterCollider not found!");
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
        CheckForLevelInteraction();

        GroundCheck();        
    }

    private void UpdateAnimator()
    {
        m_animator.SetFloat("Forward", m_forward);
        m_animator.SetFloat("Speed", new Vector3(m_rigidBody.velocity.x, 0.0f, m_rigidBody.velocity.z).magnitude / 5.5f);
        m_animator.SetFloat("Turn", m_turn);
        m_animator.SetFloat("ForwardIncline", m_forwardIncline);
        
        if (m_grounded && !m_quickTurning)
        {
            float runCycle = Mathf.Repeat(m_animator.GetCurrentAnimatorStateInfo(0).normalizedTime + m_RunCycleLegOffset, 1);
            m_jumpLeg = (runCycle < 0.5f ? 1 : -1) * m_forward;
            m_animator.SetFloat("JumpLeg", m_jumpLeg);
        }

        m_animator.SetBool("Grounded", m_grounded);
        m_animator.SetBool("Jumping", m_jumping);
        m_animator.SetBool("Crouching", m_crouching);
        m_animator.SetBool("LedgeHang", m_ledgeGrab);
        m_animator.SetBool("LedgeClimb", m_ledgeClimb);
        m_animator.SetBool("QuickTurn", m_quickTurn);
    }

    private void OnAnimatorMove()
    {
        if (Time.timeScale <= 0.0f)
        {
            return;
        }

        if (m_ledgeGrab /*|| m_ledgeClimb || m_ledgeClimbing*/)
        {
            LedgeMove();
            return;
        }

        Vector3 v = m_animator.deltaPosition / Time.deltaTime;

        if (m_rigidBody.useGravity)
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
        
    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            if (m_grounded)
            {
                transform.position = Vector3.Lerp(transform.position, transform.position + collision.contacts[0].normal * 0.1f, 3.0f * Time.deltaTime);
            }
            else
            {
                float ang = Mathf.Max(Vector3.Dot(m_rigidBody.velocity, -collision.contacts[0].normal), 0.0f);
                m_rigidBody.velocity = new Vector3(m_rigidBody.velocity.x * (1.0f - ang), m_rigidBody.velocity.y, m_rigidBody.velocity.z * (1.0f - ang));
            }

            m_levelContactPointA = collision.contacts[0];
            m_levelContactPointB = collision.contacts[collision.contacts.Length - 1];

            m_touchingLevel = true;

            //CheckForLevelInteraction();
        }
    }

    private void OnCollisionStay(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            if (m_grounded)
            {
                transform.position = Vector3.Lerp(transform.position, transform.position + collision.contacts[0].normal * 0.1f, 3.0f * Time.deltaTime);
            }

            m_levelContactPointA = collision.contacts[0];
            m_levelContactPointB = collision.contacts[collision.contacts.Length - 1];

            m_touchingLevel = true;

            //CheckForLevelInteraction();
        }
    }

    private void OnCollisionExit(Collision collision)
    {
        if (!m_grounded && !m_groundReset)
        {
            StartCoroutine(ResetOnGround(collision));
            return;
        }

        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = new ContactPoint();
            m_levelContactPointB = new ContactPoint();

            m_touchingLevel = false;
            CheckForLevelInteraction(); //clear interaction flags
        }
    }

    private IEnumerator ResetOnGround (Collision collision)
    {
        m_groundReset = true;
        while (!m_grounded)
        {
            yield return null;
        }

        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = new ContactPoint();
            m_levelContactPointB = new ContactPoint();

            m_touchingLevel = false;
            CheckForLevelInteraction(); //clear interaction flags
        }

        m_groundReset = false;
        yield return null;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(m_levelContactPointA.point, 0.05f);
        Gizmos.DrawWireSphere(m_levelContactPointB.point, 0.05f);
        Gizmos.DrawLine(m_levelContactPointA.point, m_levelContactPointA.point + m_levelContactPointA.normal);
        Gizmos.DrawLine(m_levelContactPointB.point, m_levelContactPointB.point + m_levelContactPointB.normal);

        Gizmos.color = Color.magenta;

        if (m_leftHandHoldFound)
        {
            Gizmos.DrawWireSphere(m_leftHandLedgeGrab.point, 0.05f);
        }

        if (m_rightHandHoldFound)
        {
            Gizmos.DrawWireSphere(m_rightHandLedgeGrab.point, 0.05f);
        }
    }

    #endregion

    #region MovementFunctions

    private void CheckForLevelInteraction (bool goingtoTouch = false)
    {
        // ADD "FENCE HOP" LATER!!!
        // ADD "FENCE HOP" LATER!!!
        // ADD "FENCE HOP" LATER!!!
        // ADD "FENCE HOP" LATER!!!
        // ADD "FENCE HOP" LATER!!!
        // ADD "FENCE HOP" LATER!!!
        
        if (m_ledgeGrab || m_ledgeClimbing || m_ledgeClimb) // ledge grab ended by ledge move...
        {
            return;
        }

        if (!m_touchingLevel && !goingtoTouch)
        {
            // Clear all interaction flags...
            m_leftHandHoldFound = false;
            m_rightHandHoldFound = false;
            m_ledgeGrab = false;
            m_wallRun = false;
            m_wallClimb = false;
            return;
        }
        
        if (goingtoTouch) // predict level hits...
        {
            Vector3 p1 = m_characterCollider.center - transform.up * m_characterCollider.height * 0.25f, p2 = m_characterCollider.center + transform.up * m_characterCollider.height * 0.5f;
            p1 = transform.TransformPoint(p1);
            p2 = transform.TransformPoint(p2);
            RaycastHit[] hits = Physics.CapsuleCastAll(p1, p2, m_characterCollider.radius, transform.forward, 0.3f, LayerMask.GetMask("Default"));
            if (hits.Length > 0)
            {
                // NEED TO STOP USING CONTACT POINTS!!!
                // NEED TO STOP USING CONTACT POINTS!!!
                // NEED TO STOP USING CONTACT POINTS!!!
                // NEED TO STOP USING CONTACT POINTS!!!
                // NEED TO STOP USING CONTACT POINTS!!!
                // NEED TO STOP USING CONTACT POINTS!!!
            }
        }
                
        Vector3 lerpnorm = Vector3.Lerp(m_levelContactPointA.normal, m_levelContactPointB.normal, 0.5f);
        m_facingWall = -Vector3.Dot(transform.forward, lerpnorm);

        if (m_facingWall < 0.5f) // not facing wall enough
        {
            // Clear all interaction flags...
            m_ledgeGrab = false;
            m_wallRun = false;
            m_wallClimb = false;
            return;
        }
        else if (!m_grounded) // turn to face wall
        {
            FaceDirection(-lerpnorm);
        }

        m_leftHandHoldFound = Physics.Raycast(transform.position + transform.TransformVector(new Vector3(-0.5f, 5.0f, 0.4f)), -transform.up, out m_leftHandLedgeGrab, 5.0f, LayerMask.GetMask("Default"));
        m_rightHandHoldFound = Physics.Raycast(transform.position + transform.TransformVector(new Vector3(0.5f, 5.0f, 0.4f)), -transform.up, out m_rightHandLedgeGrab, 5.0f, LayerMask.GetMask("Default"));

        //Debug.Log("m_leftHandHoldFound == " + m_leftHandHoldFound.ToString() + " ; m_rightHandHoldFound == " + m_rightHandHoldFound.ToString());

        // ledge grab check        
        if (!m_ledgeGrab && !m_ledgeClimbing && (m_rightHandHoldFound && m_leftHandHoldFound))
        {
            if (Mathf.Abs(m_leftHandLedgeGrab.point.y - m_rightHandLedgeGrab.point.y) < 0.3f) // make sure ledge not too slanted
            {
                float avgY = (m_leftHandLedgeGrab.point.y + m_rightHandLedgeGrab.point.y) / 2.0f;

                if (avgY < transform.position.y + m_characterHeight - 0.15f)
                {
                    //Debug.Log("ledge to low! avgY == " + avgY.ToString() + " ; character at " + (transform.position.y + m_characterHeight - 0.15f).ToString());
                    m_ledgeGrab = false;
                }
                else if (avgY > transform.position.y + m_characterHeight + 0.05f)
                {
                    //Debug.Log("ledge to high!");
                    m_ledgeGrab = false;
                }
                else if (m_move.y >= -0.75f)
                {
                    Debug.Log("grab ledge!");
                    m_ledgeGrab = true;                    
                }
            }
        }
        else if (!m_leftHandHoldFound || !m_rightHandHoldFound)
        {
            m_ledgeGrab = false; //missing a hand hold
        }        
    }
    
    private void LedgeMove () //called by OnAnimatorMove()...
    {
        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);
        if (!animState.IsName("LedgeHang Blend Tree"))
        {
            return;
        }
        
        if (m_rigidBody.useGravity)
        {
            m_rigidBody.useGravity = false;
        }

        if (m_grounded)
        {
            m_grounded = false;
        }

        m_leftHandHoldFound = Physics.Raycast(transform.position + transform.TransformVector(new Vector3(-0.5f, 5.0f, 0.425f)), -transform.up, out m_leftHandLedgeGrab, 5.0f, LayerMask.GetMask("Default"));
        m_rightHandHoldFound = Physics.Raycast(transform.position + transform.TransformVector(new Vector3(0.5f, 5.0f, 0.425f)), -transform.up, out m_rightHandLedgeGrab, 5.0f, LayerMask.GetMask("Default"));
        
        if (m_move.y > 0.75f)
        {
            m_ledgeClimb = true;            
        }
        else if (m_move.y < -0.75f)
        {
            m_ledgeGrab = false;            
            m_rigidBody.useGravity = true;
        }
        
        if (m_ledgeClimb)
        {
            LedgeClimb();
            return;
        }
        
        m_rigidBody.velocity = Vector3.zero;

        transform.position = Vector3.Lerp(transform.position, Vector3.Lerp(m_leftHandLedgeGrab.point, m_rightHandLedgeGrab.point, 0.5f) + transform.rotation * new Vector3(0.0f, -1.675f, -0.425f) , 30.0f * Time.deltaTime); //+ transform.right * m_turn
    }    

    private void LedgeClimb ()
    {
        if (!m_ledgeClimbing)
        {
            StartCoroutine(ClimbingLedge());
        }
    }

    private IEnumerator ClimbingLedge ()
    {   
        if ((!m_leftHandHoldFound || !m_rightHandHoldFound) || !m_ledgeGrab)
        {
            m_ledgeClimbing = false;
            yield break;
        }
        
        m_ledgeClimbing = true;
        m_ledgeGrab = false;

        Vector3 midHand = Vector3.Lerp(m_leftHandLedgeGrab.point, m_rightHandLedgeGrab.point, 0.5f);
        Vector3 climbTo = transform.position + transform.forward * 0.425f;
        climbTo.y = midHand.y;

        //Vector3 climbTo = Vector3.Lerp(m_leftHandLedgeGrab.point, m_rightHandLedgeGrab.point, 0.5f) + transform.forward * 0.3f;
        
        AnimatorStateInfo animInfo = m_animator.GetCurrentAnimatorStateInfo(0);
        Vector3 startPos = transform.position;
        
        while (!animInfo.IsName("LedgeClimb State"))
        {
            animInfo = m_animator.GetCurrentAnimatorStateInfo(0);
            transform.position = startPos;
            yield return null;
        }

        do
        {
            Debug.DrawLine(startPos, climbTo, Color.red);

            //transform.position = Vector3.Lerp(startPos, startPos + Vector3.up * 10.0f, animInfo.normalizedTime);

            //transform.position = Vector3.Lerp(startPos, climbTo, animInfo.normalizedTime);

            transform.position = Vector3.Lerp(startPos, climbTo, animInfo.normalizedTime * animInfo.normalizedTime * animInfo.normalizedTime * animInfo.normalizedTime * animInfo.normalizedTime);

            //transform.position = new Vector3(Mathf.Lerp(startPos.x, climbTo.x, animInfo.normalizedTime * animInfo.normalizedTime), Mathf.Lerp(startPos.y, climbTo.y, animInfo.normalizedTime), Mathf.Lerp(startPos.z, climbTo.z, animInfo.normalizedTime * animInfo.normalizedTime));

            animInfo = m_animator.GetCurrentAnimatorStateInfo(0);
            yield return null;
        } while (animInfo.normalizedTime < 0.999 && animInfo.IsName("LedgeClimb State"));
        
        m_ledgeGrab = false;        
        m_ledgeClimb = false;
        m_ledgeClimbing = false;        
        m_grounded = true;
        yield return null;
    }

    private void FaceDirection (Vector3 dir)
    {
        if (!m_facingDirection)
        {
            StartCoroutine(FacingDirection(dir));
        }
    }

    private IEnumerator FacingDirection (Vector3 dir)
    {
        m_facingDirection = true;

        dir = Vector3.ProjectOnPlane(dir, Vector3.up).normalized;

        float facingDir = Vector3.Dot(transform.forward, dir);

        Quaternion tarRot = Quaternion.LookRotation(dir, transform.up);

        while (facingDir < 0.99f)
        {            
            transform.rotation = Quaternion.RotateTowards(transform.rotation, tarRot, 15.0f);
            facingDir = Vector3.Dot(transform.forward, dir);
            yield return null;
        }

        transform.rotation = tarRot;
        
        yield return null;
        m_facingDirection = false;
    }

    private void ApplyRotation ()
    {
        if (m_facingDirection) //probably unecessary
        {
            return;
        }

        // In addition to root rotation in the animation
        float turnSpeed = Mathf.Lerp(m_StationaryTurnSpeed, m_MovingTurnSpeed / Mathf.Max(1.0f, m_forward), m_forward);
        transform.Rotate(0, m_turn * turnSpeed * Time.deltaTime, 0);
    }

    private void QuickTurn ()
    {
        if (!m_quickTurning /*&& !m_facingDirection*/) //probably unecessary to check m_facingDirection
        {
            Vector3 move3d = new Vector3(m_move.x, 0.0f, m_move.y);
            move3d = transform.TransformDirection(move3d);
            Quaternion tarRot = Quaternion.LookRotation(move3d, Vector3.up);

            StartCoroutine(QuickTurning(transform.rotation, tarRot));
        }
    }

    private IEnumerator QuickTurning (Quaternion startRot, Quaternion tarRot)
    {
        m_quickTurn = false;
        m_quickTurning = true;
        m_headLook = false;

        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);
        
        float ang = Quaternion.Angle(startRot, tarRot);        
        //if (animState.IsName("QuickTurnAroundRightFoot"))
        if (m_jumpLeg > 0.0f)
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
        if (m_jumping || m_ledgeGrab || m_ledgeClimbing || m_ledgeClimb)
        {
            return;
        }

        if (!m_grounded && m_rigidBody.velocity.y > 0.0f)
        {
            return;
        }

        Vector3 kneeHeightPos = transform.position + transform.up * 0.5f; //0.5f being ~character_height - capsule_height

        if (Physics.Raycast(kneeHeightPos, -transform.up, out m_groundAt, 1.0f + ((m_rigidBody.useGravity) ? 0.5f : 0.0f), ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            float inclineCheck = Vector3.Dot(m_groundAt.normal, Vector3.up);

            if (inclineCheck >= 0.5f)
            {
                /*AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);
                if (animState.IsName("LeftFootFalling") || animState.IsName("RightFootFalling"))
                {  
                    return;
                }*/

                if (m_rigidBody.useGravity)
                {
                    if ((kneeHeightPos - m_groundAt.point).magnitude > 1.0f)
                    {
                        m_grounded = true;
                        return;
                    }
                }

                m_grounded = true;
                m_rigidBody.useGravity = false;                
                
                float curY = transform.position.y, groundY = m_groundAt.point.y;
                float setY = Mathf.Lerp(curY, groundY - m_sink, 10.0f * Time.deltaTime);
                transform.position = new Vector3(transform.position.x, setY, transform.position.z);

                Vector3 projNorm = Vector3.ProjectOnPlane(m_groundAt.normal, transform.right).normalized;
                
                m_forwardIncline = Mathf.Lerp(m_forwardIncline, -Vector3.Dot(projNorm, transform.forward), 5.0f * Time.deltaTime);

                return;
            }
        }

        //m_grounded = false;
        //m_rigidBody.useGravity = true;

        //Do Foot Fall Check
        if (!m_footFallIK.ISLeftFootGrounded() && !m_footFallIK.ISRightFootGrounded())
        {
            m_grounded = false;
            m_rigidBody.useGravity = true;
        }
    }

    public void Move (Vector2 move, bool fast)
    {
        if (fast)
        {
            move *= 2.0f;
        }

        //Rotate move relative to camera rig
        Vector3 move3d = new Vector3(move.x, 0.0f, move.y);
        Quaternion rot = Quaternion.Euler(0.0f, m_camera.transform.rotation.eulerAngles.y - transform.rotation.eulerAngles.y, 0.0f);
        move3d = rot * move3d;

        move.x = move3d.x;
        move.y = move3d.z;

        m_move = Vector2.Lerp(m_move, move, 10.0f * Time.deltaTime);
        
        // Check for clear path (to adjust move input only; not level interactions)
        Vector3 p1 = m_characterCollider.center - transform.up * m_characterCollider.height * 0.25f, p2 = m_characterCollider.center + transform.up * m_characterCollider.height * 0.5f;
        p1 = transform.TransformPoint(p1);
        p2 = transform.TransformPoint(p2);
        RaycastHit pathHit;
        //bool pathClear = !Physics.CapsuleCast(p1, p2, m_characterCollider.radius, transform.forward, out pathHit, 2.0f, LayerMask.GetMask("Default"));
        bool pathClear = !Physics.SphereCast(p2, m_characterCollider.radius, transform.forward, out pathHit, 2.0f, LayerMask.GetMask("Default"));
                
        if (move.y < -1.5f && !m_quickTurning && m_grounded)  // Want quick turn
        {            
            if (!pathClear && Vector3.Dot(pathHit.normal, Vector3.up) < 0.5f)
            {
                m_quickTurn = false;                
            }
            else
            {
                m_quickTurn = true;
                m_move = move;
            }
        }

        m_forward = m_move.y;
        m_turn = m_move.x;

        //NOT GOOD ENOUGH!!! CAN'T RUN UP STAIRS
        if (!pathClear && m_forward > 0.0f) 
        {
            Vector2 a = new Vector2(transform.position.x, transform.position.z), b = new Vector2(pathHit.point.x, pathHit.point.z);

            float d = Vector2.Distance(a, b);
            
            float n1 = 0.8f, n2 = 1.0f;
            float c = Mathf.Clamp((Vector3.Dot(-transform.forward, pathHit.normal) - n1) / (n2 - n1), 0.0f, 1.0f); 
            
            m_forward *= Mathf.Lerp(1.0f, Mathf.SmoothStep(0.0f, 1.0f, Mathf.Min(1.0f, d / 2.0f)), c);
                          
            CheckForLevelInteraction(true);            
        }
        
        AnimatorStateInfo animState = m_animator.GetCurrentAnimatorStateInfo(0);
        if ((animState.IsName("Normal Locomotion Blend Tree") || animState.IsName("Crouching Locomotion Blend Tree")) && !m_quickTurning)
        {
            ApplyRotation();
        }
        else if (((animState.IsName("QuickTurnAroundLeftFoot") || animState.IsName("QuickTurnAroundRightFoot"))))
        {
            QuickTurn();            
        }
    }

    public void Crouch (bool crouch)
    {
        /*float inclineCheck = Vector3.Dot(m_groundAt.normal, Vector3.up);
        if (inclineCheck < 0.85f)
        {
            m_crouching = false;
        }
        else
        {
            m_crouching = crouch;
        }*/

        m_crouching = crouch;
    }

    public void Jump ()
    {
        if (m_jumping || !m_grounded || m_jumpOnCD || m_quickTurning || m_ledgeGrab || m_ledgeClimb)
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
        m_jumpOnCD = true;

        m_rigidBody.useGravity = true;
        //Vector3 push = transform.TransformDirection(new Vector3(m_move.x, 0.0f, m_move.y) * 200.0f);
        Vector3 push = transform.TransformDirection(new Vector3(m_turn, 0.0f, m_forward) * 200.0f);
        if (!m_touchingLevel)
        {
            m_rigidBody.AddForce(push, ForceMode.Impulse);
        }

        m_rigidBody.AddForce(Vector3.up * 400.0f, ForceMode.Impulse);

        // Wait for jump to start
        while (!animState.IsName("Jump Blend Tree"))
        {
            //Debug.Log("1");
            animState = m_animator.GetCurrentAnimatorStateInfo(0);
            yield return null;
        }

        // Wait for jump to end
        while ((animState.IsName("Jump Blend Tree")) && animState.normalizedTime < 0.99f)
        {
            //Debug.Log("2");
            animState = m_animator.GetCurrentAnimatorStateInfo(0);
            
            //m_rigidBody.AddForce(Vector3.up * 2000.0f + push);
            yield return null;
        }
        
        m_jumping = false;
        
        // Wait for jump cooldown
        
        float startCoolDown = Time.time;
        while (startCoolDown + m_jumpCoolDown > Time.time)
        {
            yield return null;
        }
        m_jumpOnCD = false;

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
    
    public bool IsCrouching ()
    {
        return m_crouching;
    }

    public void SetSink (float sink)
    {
        m_sink = Mathf.Clamp(sink, -0.45f, 0.45f);

        //transform.position = new Vector3(transform.position.x, transform.position.y - sink, transform.position.z);        
    }

    public float GetSink ()
    {
        return m_sink;
    }

    #endregion
}
