using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AkaiProjectedCollisionDetector : MonoBehaviour
{
    private Rigidbody m_rigidBody = null;
    private ContactPoint m_levelContactPointA = new ContactPoint(), m_levelContactPointB = new ContactPoint();    
    private bool m_touchingLevel = false;

    // Use this for initialization
    void Awake ()
    {
        gameObject.layer = LayerMask.NameToLayer("CharacterGhost");
        gameObject.name = "AkaiProjectedCollisionDetector";

        gameObject.AddComponent<Rigidbody>();
        m_rigidBody = GetComponent<Rigidbody>();
        //m_rigidBody.isKinematic = true;
        m_rigidBody.useGravity = false;
        m_rigidBody.drag = Mathf.Infinity;
        m_rigidBody.angularDrag = Mathf.Infinity;
	}
	
	// Update is called once per frame
	void Update ()
    {
		
	}

    public ContactPoint GetLevelContactPointA ()
    {
        return m_levelContactPointA;
    }

    public ContactPoint GetLevelContactPointB ()
    {
        return m_levelContactPointB;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.black;
        Gizmos.DrawWireSphere(m_levelContactPointA.point, 0.05f);
        Gizmos.DrawWireSphere(m_levelContactPointB.point, 0.05f);
        Gizmos.DrawLine(m_levelContactPointA.point, m_levelContactPointA.point + m_levelContactPointA.normal);
        Gizmos.DrawLine(m_levelContactPointB.point, m_levelContactPointB.point + m_levelContactPointB.normal);        
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = collision.contacts[0];
            m_levelContactPointB = collision.contacts[collision.contacts.Length - 1];

            m_touchingLevel = true;

            //Debug.Log("projection collided with " + collision.gameObject.name);
        }
    }

    private void OnCollisionStay(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = collision.contacts[0];
            m_levelContactPointB = collision.contacts[collision.contacts.Length - 1];

            m_touchingLevel = true;
        }
    }

    private void OnCollisionExit(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = new ContactPoint();
            m_levelContactPointB = new ContactPoint();

            m_touchingLevel = false;
        }
    }
}
