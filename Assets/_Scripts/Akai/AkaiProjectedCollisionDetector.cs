using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AkaiProjectedCollisionDetector : MonoBehaviour
{
    private ContactPoint m_levelContactPointA = new ContactPoint(), m_levelContactPointB = new ContactPoint();    
    private bool m_touchingLevel = false;

    // Use this for initialization
    void Start ()
    {
        gameObject.layer = LayerMask.NameToLayer("CharacterGhost");
        gameObject.name = "AkaiProjectedCollisionDetector";
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

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.layer == LayerMask.NameToLayer("Default"))
        {
            m_levelContactPointA = collision.contacts[0];
            m_levelContactPointB = collision.contacts[collision.contacts.Length - 1];

            m_touchingLevel = true;
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
