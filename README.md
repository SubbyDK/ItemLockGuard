# 🛡️ ItemLockGuard

**ItemLockGuard** is a lightweight utility for World of Warcraft (Vanilla 1.12.1) designed to protect your valuable gear from accidental **Disenchanting** or **Selling**. 

---

## 📜 Backstory

I created this addon after a heartbreaking accident where I disenchanted my **[\[Gressil, Dawn of Ruin\]](https://www.wowhead.com/classic/item=23054)**.  
After farming it twice, I decided that a third time was not an option.  
This tool is built to ensure that no one else (and especially not me) has to lose their hard-earned loot to a misclick.

---

## ⚠️ Disclaimer

**Use at your own risk.**  
While this addon is designed to prevent accidental disenchanting and selling, the author is not responsible for any lost items, bugs, or unintended behavior.  
Always double-check your items before performing irreversible actions.

---

## 🚀 Features

* 🔒 **Item Locking:** Secure any item in your bags, bank, or character equipment.
* 🚫 **Action Blocking:** Automatically intercepts Disenchanting or Selling if an item is locked.
* 🔴 **Visual Feedback:** Displays a 🚫 on protected items for instant identification.
* 📦 **Addon Compatibility:** Full support for **[pfUI](https://github.com/me0wg4ming/pfUI)** frames as well as **standard Blizzard UI** (other bag addons may also work).
* 🌍 **Global Support:** Localized for English, German, French, Spanish, Russian, Chinese, Italian, and Korean  
  (Note: Only English has been fully tested).

---

## 📥 Installation

1. Download the repository.
2. Extract the folder into your `Interface\AddOns\` directory.
3. **Important:** Rename the folder to `ItemLockGuard` (remove any suffixes like `-master`).
4. Restart World of Warcraft or reload your UI.

---

## 🎮 How to Use

| Action | Command |
| :--- | :--- |
| **Toggle Lock** | `Ctrl` + `Right-Click` on an item |
| **Status Message** | Check your chat frame for confirmation |
| **Visual Check** | Look for the 🚫 icon on the top-right of the item slot |

---

## 🛠️ Technical Details

* 💾 **Persistent Data:** Your locked items are saved locally per character in the `WTF` folder.

---

## 👥 Credits

* **Author:** Subby
* **Version:** 1.0.0
* **Game Version:** 1.12.1 (Classic/Vanilla)

---

### 💻 Developer Note
If you are looking to modify the addon, all protection logic is hooked into the standard `UseContainerItem`, `PickupContainerItem`, and spellcasting functions to ensure maximum security.

```lua
-- Protection check example
if (IsProtected(link)) then
    -- Blocks the action and alerts the player
    UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
end
```
