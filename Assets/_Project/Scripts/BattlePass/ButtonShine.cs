using UnityEngine;
using UnityEngine.UI;

public class ButtonShineReveal : MonoBehaviour
{
    public RectTransform shineRect;
    public RectTransform glowRect;
    public float speed = 0.5f;
    public float pause = 2f;

    float timer;
    float startX, endX;

    void Start()
    {
        var parent = shineRect.parent as RectTransform;
        float parentW = parent.rect.width;
        float shineW = shineRect.rect.width;

        startX = -parentW - shineW;
        endX = parentW + shineW;
    }

    void Update()
    {
        timer += Time.deltaTime;

        if (timer < speed)
        {
            float t = timer / speed;
            float x = Mathf.Lerp(startX, endX, t);
            shineRect.anchoredPosition = new Vector2(x, 0);

            glowRect.anchoredPosition = new Vector2(-x, 0);
        }
        else if (timer > speed + pause)
        {
            timer = 0;
        }
    }
}