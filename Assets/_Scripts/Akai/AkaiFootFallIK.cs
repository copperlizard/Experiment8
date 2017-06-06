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

            if (m_rightFootTransform == null)
            {
                Debug.Log("m_rightFootTranform not found!");
            }
        }


    }
	
	// Update is called once per frame
	void Update ()
    {
		
	}

    private void OnDrawGizmos()
    {
        if (!Application.isPlaying)
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
        
    }
}
