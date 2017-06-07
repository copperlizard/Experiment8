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

    private float m_leftFootWeight, m_rightFootWeight;

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
        m_leftFootWeight = m_animator.GetFloat("LeftFootWeight");
        m_rightFootWeight = m_animator.GetFloat("RightFootWeight");

        Vector3 leftStartPos = new Vector3(m_leftFootTransform.position.x, transform.position.y + m_maxFootLift, m_leftFootTransform.position.z);
        Vector3 rightStartPos = new Vector3(m_rightFootTransform.position.x, transform.position.y + m_maxFootLift, m_rightFootTransform.position.z);

        if (Physics.Raycast(leftStartPos, -transform.up, out m_leftFootHit, m_maxFootLift * 2.0f, ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            m_leftFootTarPos = m_leftFootHit.point;
        }
        else
        {
            m_leftFootTarPos = m_leftFootTransform.position;
        }

        if (Physics.Raycast(rightStartPos, -transform.up, out m_rightFootHit, m_maxFootLift * 2.0f, ~LayerMask.GetMask("Character", "CharacterBody")))
        {
            m_rightFootTarPos = m_rightFootHit.point;
        }
        else
        {
            m_rightFootTarPos = m_rightFootTransform.position;
        }

        
        float leftSink = (transform.position.y - m_leftFootTarPos.y); 
        float rightSink = (transform.position.y - m_rightFootTarPos.y);

        //float sink = Mathf.Abs(m_leftFootTarPos.y - m_rightFootTarPos.y); //No way to weigh feet???

        //Debug.Log("sinksink == " + sink.ToString());

        Debug.Log("leftSink == " + leftSink.ToString() + " ; rightSink == " + rightSink.ToString());

        float sink = leftSink + rightSink;

        Debug.Log("sink == " + sink.ToString());

        //m_akaiController.SetSink(sink);
        m_akaiController.SetSink(0.2f);
    }
}
