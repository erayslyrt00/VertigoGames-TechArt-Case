using System.Collections;
using UnityEngine;
using UnityEngine.UI;

// Bursts currency icons at a spawn point and flies them to a target label.
public class CurrencyCollectFx : MonoBehaviour
{
    public static CurrencyCollectFx Instance { get; private set; }

    public RectTransform canvasRect;   // a canvas the holder is parented under
    public Camera uiCamera;            // leave null for Screen Space - Overlay
    public Image iconPrefab;           // the flying coin image
    public RectTransform spawnPoint;   // where the burst starts; null = canvas centre
    public int sortingOrder = 100;     // holder canvas order, above the rest of the UI

    [Header("Burst")]
    public int count = 12;
    public float scatterRadius = 160f;
    public float iconSize = 110f;
    public float burstDuration = 0.25f;
    public float holdDuration = 0.12f;

    [Header("Fly")]
    public float flyDuration = 0.45f;
    public float stagger = 0.04f;
    public float endScale = 0.6f;
    public Vector2 targetOffset;       // nudge so icons land on the icon, not the number

    RectTransform holder;

    void Awake()
    {
        Instance = this;
    }

    RectTransform Holder()
    {
        if (holder != null) return holder;

        var go = new GameObject("CurrencyCollectFx_Holder", typeof(RectTransform), typeof(Canvas));
        holder = (RectTransform)go.transform;
        holder.SetParent(canvasRect, false);
        holder.anchorMin = Vector2.zero;
        holder.anchorMax = Vector2.one;
        holder.offsetMin = Vector2.zero;
        holder.offsetMax = Vector2.zero;

        var c = go.GetComponent<Canvas>();
        c.overrideSorting = true;
        c.sortingOrder = sortingOrder;
        return holder;
    }

    public void Play(Sprite sprite, RectTransform target)
    {
        if (sprite == null || target == null || iconPrefab == null || canvasRect == null) return;
        StartCoroutine(Run(sprite, target));
    }

    IEnumerator Run(Sprite sprite, RectTransform target)
    {
        RectTransform parent = Holder();
        Vector2 origin = spawnPoint != null ? ToCanvasLocal(spawnPoint.position) : Vector2.zero;
        var icons = new RectTransform[count];
        var from = new Vector2[count];
        var scatter = new Vector2[count];

        for (int i = 0; i < count; i++)
        {
            Image img = Instantiate(iconPrefab, parent);
            img.sprite = sprite;
            img.raycastTarget = false;
            RectTransform rt = img.rectTransform;
            rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f);
            rt.localScale = Vector3.one;
            rt.localRotation = Quaternion.identity;
            rt.sizeDelta = new Vector2(iconSize, iconSize);
            rt.anchoredPosition = origin;
            scatter[i] = Random.insideUnitCircle.normalized * scatterRadius * Random.Range(0.5f, 1f);
            icons[i] = rt;
        }

        // burst out from the spawn point
        float t = 0f;
        while (t < burstDuration)
        {
            t += Time.unscaledDeltaTime;
            float k = EaseOut(t / burstDuration);
            for (int i = 0; i < count; i++)
                icons[i].anchoredPosition = origin + scatter[i] * k;
            yield return null;
        }
        for (int i = 0; i < count; i++) from[i] = icons[i].anchoredPosition;

        if (holdDuration > 0f) yield return new WaitForSecondsRealtime(holdDuration);

        // fly to the target, staggered
        int landed = 0;
        for (int i = 0; i < count; i++)
            StartCoroutine(Fly(icons[i], from[i], target, i * stagger, () => landed++));

        while (landed < count) yield return null;
    }

    IEnumerator Fly(RectTransform rt, Vector2 from, RectTransform target, float delay, System.Action onDone)
    {
        if (delay > 0f) yield return new WaitForSecondsRealtime(delay);

        float t = 0f;
        while (t < flyDuration)
        {
            t += Time.unscaledDeltaTime;
            float k = EaseIn(t / flyDuration);
            Vector2 to = ToCanvasLocal(target.position) + targetOffset; // tracks the label if it moves
            rt.anchoredPosition = Vector2.Lerp(from, to, k);
            rt.localScale = Vector3.one * Mathf.Lerp(1f, endScale, k);
            yield return null;
        }

        Destroy(rt.gameObject);
        onDone?.Invoke();
    }

    Vector2 ToCanvasLocal(Vector3 worldPos)
    {
        Vector2 screen = RectTransformUtility.WorldToScreenPoint(uiCamera, worldPos);
        RectTransformUtility.ScreenPointToLocalPointInRectangle(canvasRect, screen, uiCamera, out Vector2 local);
        return local;
    }

    static float EaseOut(float x) => 1f - (1f - x) * (1f - x);
    static float EaseIn(float x) => x * x;
}
