using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(AkaiController))]
[RequireComponent(typeof(Animator))]
public class AkaiFootFallIK : MonoBehaviour
{
    [SerializeField]
    private float m_footRadius = 0.125f, m_maxFootLift = 0.5f;

    private AkaiController m_akaiController;

    private Animator m_animator;

    private Transform m_leftFootTransform, m_rightFootTransform;

    private Vector3 m_leftFootTarPos, m_rightFootTarPos;

    private RaycastHit m_leftFootHit, m_rightFootHit;

    private float m_leftFootWeight, m_rightFootWeight, m_leftFootHeightOffset, m_rightFootHeightOffset;

	// Use this for initialization
	void Start ()
    {
        m_akaiController = GetComponent<AkaiController>();
        if (m_akaiController == null)
        {
            Debug.Log("m_akaiController not found!");
        }

        m_animator = GetComponent<Animator>();
        if (m_animator == null)
        {
            Debug.Log("m_animator not found!");
        }
        else
        {
            m_leftFootTransform = m_animator.GetBoneTransform(HumanBodyBones.LeftFoot);
            m_rightFootTransform = m_animator.GetBoneTransform(HumanBodyBones.RightFoot);

            if (m_leftFootTransform == null)
            {
                Debug.Log("m_leftFootTransform not found!");
            }
            else
            {
                m_leftFootHeightOffset = m_leftFootTransform.position.y - transform.position.y;
            }

            if (m_rightFootTransform == null)
            {
                Debug.Log("m_rightFootTranform not found!");
            }
            else
            {
                m_rightFootHeightOffset = m_rightFootTransform.position.y - transform.position.y;
            }
        }


    }
	
	// Update is called once per frame
	void Update ()
    {
		
	}

    private void FixedUpdate ()
    {
        
    }

    private void OnDrawGizmos()
    {
        if (!Application.isPlaying || !m_akaiController.IsGrounded())
        {
            return;
        }

        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(m_leftFootTransform.position, m_footRadius);
        Gizmos.DrawWireSphere(m_rightFootTransform.position, m_footRadius);

        Gizmos.color = Color.blue;
        Gizmos.DrawWireSphere(m_leftFootTarPos, m_footRadius);
        Gizmos.DrawWireSphere(m_rightFootTarPos, m_footRadius);
    }

    private void OnAnimatorIK(int layerIndex)
    {
        if (!m_akaiController.IsGrounded())
        {
            return;
        }

        Vector3 leftStartPos = new Vector3(m_leftFootTransform.position.x, transform.position.y + m_maxFootLift, m_leftFootTransform.position.z);
        Vector3 rightStartPos = new Vector3(m_rightFootTransform.position.x, transform.position.y + m_maxFootLift, m_rightFootTransform.position.z);

        if (Physics.Raycast(leftStartPos, -transform.up, out m_leftFootHit, m_maxFootLift * 2.0f, ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            m_leftFootTarPos = m_leftFootHit.point + transform.up * m_footRadius;
        }
        else
        {
            m_leftFootTarPos = m_leftFootTransform.position;
        }

        if (Physics.Raycast(rightStartPos, -transform.up, out m_rightFootHit, m_maxFootLift * 2.0f, ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            m_rightFootTarPos = m_rightFootHit.point + transform.up * m_footRadius;
        }
        else
        {
            m_rightFootTarPos = m_rightFootTransform.position;
        }

        m_leftFootWeight = m_animator.GetFloat("LeftFootWeight");
        m_rightFootWeight = m_animator.GetFloat("RightFootWeight");

        m_leftFootWeight = Mathf.SmoothStep(0.0f, 1.0f, m_leftFootWeight);
        m_rightFootWeight = Mathf.SmoothStep(0.0f, 1.0f, m_rightFootWeight);

        //Debug.Log("m_leftFootWeight == " + m_leftFootWeight.ToString() + " ; m_rightFootWeight == " + m_rightFootWeight.ToString());

        //float leftSink = m_leftFootTransform.position.y - m_leftFootTarPos.y, rightSink = m_rightFootTransform.position.y - m_rightFootTarPos.y;
        float leftSink = (transform.position.y - m_leftFootTarPos.y) + m_leftFootHeightOffset, rightSink = (transform.position.y - m_rightFootTarPos.y) + m_rightFootHeightOffset;

        leftSink *= m_leftFootWeight;
        rightSink *= m_rightFootWeight;

        //Debug.Log("old m_akaiController.m_sink == " + m_akaiController.GetSink().ToString());
        //Debug.Log("leftSink == " + leftSink.ToString() + " ; rightSink == " + rightSink.ToString());

        m_akaiController.SetSink(Mathf.Lerp(m_akaiController.GetSink(), ((leftSink > rightSink) ? leftSink : rightSink) + m_akaiController.GetSink(), 3.0f * Time.deltaTime));

        m_animator.SetIKPositionWeight(AvatarIKGoal.LeftFoot, m_leftFootWeight);
        m_animator.SetIKRotationWeight(AvatarIKGoal.LeftFoot, m_leftFootWeight); //* Vector3.Dot(m_leftFootHit.normal, Vector3.up)
        m_animator.SetIKPosition(AvatarIKGoal.LeftFoot, m_leftFootTarPos);
        m_animator.SetIKRotation(AvatarIKGoal.LeftFoot, Quaternion.LookRotation(Vector3.Cross(transform.right, m_leftFootHit.normal), m_leftFootHit.normal));

        m_animator.SetIKPositionWeight(AvatarIKGoal.RightFoot, m_rightFootWeight);
        m_animator.SetIKRotationWeight(AvatarIKGoal.RightFoot, m_rightFootWeight); //* Vector3.Dot(m_rightFootHit.normal, Vector3.up)
        m_animator.SetIKPosition(AvatarIKGoal.RightFoot, m_rightFootTarPos);
        m_animator.SetIKRotation(AvatarIKGoal.RightFoot, Quaternion.LookRotation(Vector3.Cross(transform.right, m_rightFootHit.normal), m_rightFootHit.normal));
    }
}
