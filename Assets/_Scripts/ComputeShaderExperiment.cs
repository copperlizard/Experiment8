using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ComputeShaderExperiment : MonoBehaviour
{
    [SerializeField]
    private ComputeShader m_computeShader;

    private RenderTexture m_texture;

    private MeshRenderer m_testMeshRenderer;
    private Material m_testMat;

    private int m_kernelHandle = 0;

	// Use this for initialization
	void Start ()
    {
        if (m_computeShader == null)
        {
            Debug.Log("m_computeShader not assigned!");
        }

        m_kernelHandle = m_computeShader.FindKernel("CSMain");
        m_texture = new RenderTexture(256, 256, 24);
        m_texture.enableRandomWrite = true;
        m_texture.Create();
                
        m_testMeshRenderer = GetComponentInChildren<MeshRenderer>();
        m_testMat = m_testMeshRenderer.sharedMaterial;

        m_testMat.SetTexture("_MainTex", m_texture);
    }
	
	// Update is called once per frame
	void Update ()
    {
        m_computeShader.SetTexture(m_kernelHandle, "Result", m_texture);
        m_computeShader.Dispatch(m_kernelHandle, 256 / 8, 256 / 8, 1);
    }
}
