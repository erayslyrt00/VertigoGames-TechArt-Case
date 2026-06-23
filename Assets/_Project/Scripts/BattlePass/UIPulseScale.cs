using UnityEngine;

public class UIPulseScale : MonoBehaviour
{
    public float restScale = 1f;
    public float pulseScale = 1.2f;
    public float pulseDuration = 0.6f;
    public float pauseDuration = 1.5f;
    public int pulseCount = 2;
    public float phaseOffset = 0f;

    RectTransform rect;
    float timer;

    void Awake()
    {
        rect = transform as RectTransform;
        timer = phaseOffset;
    }

    void OnDisable()
    {
        if (rect != null) rect.localScale = new Vector3(restScale, restScale, 1f);
    }

    void Update()
    {
        timer += Time.unscaledDeltaTime;

        float cycle = pulseDuration + pauseDuration;
        if (timer > cycle) timer -= cycle;

        float s = restScale;
        if (timer < pulseDuration)
        {
            float p = timer / pulseDuration;
            float bump = Mathf.Abs(Mathf.Sin(p * Mathf.PI * pulseCount));
            s = Mathf.Lerp(restScale, pulseScale, bump);
        }

        rect.localScale = new Vector3(s, s, 1f);
    }
}
