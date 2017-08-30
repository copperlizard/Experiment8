using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeShaderExperiment : MonoBehaviour
{
    [SerializeField]
    private Material m_waterMaterial;

    [SerializeField]
    private ComputeShader m_computeShader;

    private RenderTexture m_texture;
    private Texture2D m_2Dtexture;

    private MeshRenderer m_testMeshRenderer;
    private Material m_testMat;

    private int m_kernelHandle = 0;

	// Use this for initialization
	void Awake ()
    {
        if (m_computeShader == null)
        {
            Debug.Log("m_computeShader not assigned!");
        }

        if (m_waterMaterial == null)
        {
            Debug.Log("m_waterMaterail not assigned!");
        }
        
        m_kernelHandle = m_computeShader.FindKernel("CSMain");
        m_texture = new RenderTexture(256, 256, 24);
        m_texture.enableRandomWrite = true;
        m_texture.Create();

        m_2Dtexture = new Texture2D(m_texture.width, m_texture.height);

        m_testMeshRenderer = GetComponentInChildren<MeshRenderer>();
        m_testMat = m_testMeshRenderer.sharedMaterial;        

        m_testMat.SetTexture("_MainTex", m_texture);

        m_computeShader.SetTexture(m_kernelHandle, "Result", m_texture);
    }
        
    // Update is called once per frame
    void Update ()
    {   
        m_computeShader.SetFloat("_Time", Time.realtimeSinceStartup * 0.25f);

        m_waterMaterial.SetFloat("_realTime", Time.realtimeSinceStartup * 0.25f);
        
        m_computeShader.Dispatch(m_kernelHandle, 256 / 8, 256 / 8, 1);
    }

    public float GetWaveStrength (Vector2 pos)
    {
        RenderTexture.active = m_texture;
        m_2Dtexture.ReadPixels(new Rect(0, 0, m_texture.width, m_texture.height), 0, 0);
        m_2Dtexture.Apply();

        return 1.0f;
    }
}
