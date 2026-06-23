using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class BattlePassNode : MonoBehaviour, IPointerClickHandler
{
    public enum State { Locked, Claimable, Claimed }

    public State state;
    public int level;
    public bool levelDriven = true;
    public bool isPremium;
    public bool premiumOwned = true;
    public bool isValuable;

    bool claimed;
    bool initialized;

    public Image iconImage;
    public string displayName;

    [Header("Backgrounds")]
    public GameObject rarityBg;
    public GameObject claimableVisual;
    public GameObject claimedVisual;

    [Header("Overlays")]
    public GameObject lockedVisual;
    public GameObject redDot;

    [Header("Claim pop")]
    public float popScale = 1.15f;
    public float popDuration = 0.25f;

    [Header("Premium-locked shake")]
    public float shakeAngle = 6f;
    public float shakeDuration = 0.3f;
    public float shakeFrequency = 40f;

    public static event System.Action PremiumLockedClicked;

    Coroutine popRoutine;
    Coroutine shakeRoutine;

    public RectTransform Rect => (RectTransform)transform;
    public int Level => level;
    public bool IsCollectable => state == State.Claimable && (!isPremium || premiumOwned);
    public bool IsPremiumLocked => state == State.Claimable && isPremium && !premiumOwned;
    public bool IsValuable => isValuable;
    public Sprite Icon => iconImage != null ? iconImage.sprite : null;
    public string DisplayName => displayName;

    void OnEnable()
    {
        ApplyState();
    }

    public void OnPointerClick(PointerEventData eventData)
    {
        if (IsCollectable) Claim();
        else if (IsPremiumLocked) RejectPremium();
        else if (state == State.Locked) StartShake();
    }

    void RejectPremium()
    {
        StartShake();
        PremiumLockedClicked?.Invoke();
    }

    void StartShake()
    {
        if (shakeRoutine != null) StopCoroutine(shakeRoutine);
        shakeRoutine = StartCoroutine(Shake());
    }

    public void GrantPremium()
    {
        premiumOwned = true;
        ApplyState();

        if (isPremium && state == State.Claimable)
        {
            if (popRoutine != null) StopCoroutine(popRoutine);
            popRoutine = StartCoroutine(Pop(transform, 1f));
        }
    }

    // Rotates instead of moving so layout groups don't fight the position.
    IEnumerator Shake()
    {
        float t = 0f;
        while (t < shakeDuration)
        {
            t += Time.unscaledDeltaTime;
            float damp = 1f - t / shakeDuration;
            float angle = Mathf.Sin(t * shakeFrequency) * shakeAngle * damp;
            transform.localRotation = Quaternion.Euler(0f, 0f, angle);
            yield return null;
        }
        transform.localRotation = Quaternion.identity;
        shakeRoutine = null;
    }

    public void RefreshForLevel(int playerLevel)
    {
        if (!levelDriven)
        {
            ApplyState();
            return;
        }

        State prev = state;
        if (claimed) state = State.Claimed;
        else state = playerLevel >= level ? State.Claimable : State.Locked;
        ApplyState();

        if (initialized && prev == State.Locked && state == State.Claimable)
        {
            if (popRoutine != null) StopCoroutine(popRoutine);
            Transform t = claimableVisual != null ? claimableVisual.transform : transform;
            popRoutine = StartCoroutine(Pop(t, claimableVisual != null ? 0f : 1f));
        }
        initialized = true;
    }

    public void Claim()
    {
        claimed = true;
        state = State.Claimed;
        ApplyState();

        if (popRoutine != null) StopCoroutine(popRoutine);
        if (claimedVisual != null) popRoutine = StartCoroutine(Pop(claimedVisual.transform, 0f));
        else popRoutine = StartCoroutine(Pop(transform, 1f));
    }

    IEnumerator Pop(Transform t, float from)
    {
        float half = popDuration * 0.5f;

        float e = 0f;
        while (e < half)
        {
            e += Time.unscaledDeltaTime;
            t.localScale = Vector3.one * Mathf.Lerp(from, popScale, e / half);
            yield return null;
        }

        e = 0f;
        while (e < half)
        {
            e += Time.unscaledDeltaTime;
            t.localScale = Vector3.one * Mathf.Lerp(popScale, 1f, e / half);
            yield return null;
        }

        t.localScale = Vector3.one;
        popRoutine = null;
    }

    public void ApplyState()
    {
        // claimable + premium not owned -> show the lock over the claimable look ("UNLOCK NOW")
        bool premiumLock = isPremium && !premiumOwned && state == State.Claimable;

        if (rarityBg != null) rarityBg.SetActive(state == State.Locked);
        if (claimableVisual != null) claimableVisual.SetActive(state == State.Claimable);
        if (claimedVisual != null) claimedVisual.SetActive(state == State.Claimed);

        if (lockedVisual != null) lockedVisual.SetActive(state == State.Locked || premiumLock);
        if (redDot != null) redDot.SetActive(state == State.Claimable);
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        // deferred: toggling SetActive mid-validation makes inline-sprite TMP text throw
        UnityEditor.EditorApplication.delayCall += () =>
        {
            if (this != null) ApplyState();
        };
    }
#endif
}
