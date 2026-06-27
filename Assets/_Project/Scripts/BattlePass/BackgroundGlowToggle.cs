using UnityEngine;
using UnityEngine.UI;

// Background glow that fades out as it nears the buy button, gone past it.
public class BackgroundGlowToggle : MonoBehaviour
{
    public RectTransform button;       // buy button (moves with scroll / fill)
    public Graphic glow;               // the fixed glow sprite
    public float fadeDistance = 200f;  // distance over which it fades to 0
    public float hideOffset = 0f;      // pulls the fully-hidden point left of the button
    public bool flip;                  // invert side

    void Reset()
    {
        glow = GetComponent<Graphic>();
    }

    void Update()
    {
        if (button == null || glow == null) return;

        float gap = (button.position.x - hideOffset) - glow.rectTransform.position.x;
        if (flip) gap = -gap;

        float a = Mathf.Clamp01(gap / Mathf.Max(0.0001f, fadeDistance));
        glow.canvasRenderer.SetAlpha(a);
    }
}
