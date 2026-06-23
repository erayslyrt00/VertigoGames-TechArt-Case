using System.Collections;
using UnityEngine;
using UnityEngine.UI;

public class PremiumPromptButton : MonoBehaviour
{
    public float bounceScale = 1.15f;
    public float duration = 0.3f;

    RectTransform rect;
    Coroutine routine;

    void Awake()
    {
        rect = transform as RectTransform;

        var button = GetComponent<Button>();
        if (button != null) button.onClick.AddListener(BuyPremium);
    }

    public void BuyPremium()
    {
        foreach (var node in FindObjectsByType<BattlePassNode>(FindObjectsSortMode.None))
            node.GrantPremium();
    }

    void OnEnable()
    {
        BattlePassNode.PremiumLockedClicked += Bounce;
    }

    void OnDisable()
    {
        BattlePassNode.PremiumLockedClicked -= Bounce;
        if (rect != null) rect.localScale = Vector3.one;
    }

    void Bounce()
    {
        if (routine != null) StopCoroutine(routine);
        routine = StartCoroutine(BounceRoutine());
    }

    IEnumerator BounceRoutine()
    {
        float half = duration * 0.5f;

        float e = 0f;
        while (e < half)
        {
            e += Time.unscaledDeltaTime;
            rect.localScale = Vector3.one * Mathf.Lerp(1f, bounceScale, e / half);
            yield return null;
        }

        e = 0f;
        while (e < half)
        {
            e += Time.unscaledDeltaTime;
            rect.localScale = Vector3.one * Mathf.Lerp(bounceScale, 1f, e / half);
            yield return null;
        }

        rect.localScale = Vector3.one;
        routine = null;
    }
}
