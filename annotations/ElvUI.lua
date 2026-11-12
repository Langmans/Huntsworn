---@meta
-- Editor-only types for the part of ElvUI that Integrations\ElvUI\ uses: the methods its Toolkit
-- (ElvUI\Game\Shared\General\Toolkit.lua) adds to every frame, texture and font string. Not
-- listed in the .toc.

---@class ElvUIFrame: Button
---@field SetTemplate fun(self: ElvUIFrame, template: "Default"|"Transparent"?)
---@field SetBackdropBorderColor fun(self: ElvUIFrame, r: number, g: number, b: number, a: number?)
---@field StyleButton fun(self: ElvUIFrame, noHover: boolean?, noPushed: boolean?, noChecked: boolean?)
---@field CreateShadow fun(self: ElvUIFrame, length: number?) a shadow frame in .shadow
---@field shadow Frame? the frame's shadow, once made

---@class ElvUITexture: Texture
---@field SetTexCoords fun(self: ElvUITexture) ElvUI's icon crop

---@class ElvUIFontString: FontString
---@field FontTemplate fun(self: ElvUIFontString, font: string?, size: number?, style: string?)

---ElvUI's media (E.media), as far as Huntsworn reads it.
---@class ElvUIMedia
---@field rgbvaluecolor number[]? its "value color": { r, g, b }

---ElvUI's engine (E), ElvUI[1].
---@class ElvUIEngine
---@field media ElvUIMedia?
---@field db ElvUIProfile? the profile's settings, its plugins' among them
---@field GetModule fun(self: ElvUIEngine, name: string, silent: boolean?): ElvUISkins?

---ElvUI's Skins module (E:GetModule("Skins")), the part Huntsworn uses.
---@class ElvUISkins
---@field HandleCloseButton (fun(self: ElvUISkins, button: Button))?
---@field HandleButton (fun(self: ElvUISkins, button: Button))?
---@field HandleEditBox (fun(self: ElvUISkins, box: EditBox))?

---ElvUI's profile (E.db), as far as Huntsworn reads it: Eltruism's shadow settings.
---@class ElvUIProfile
---@field general {cropIcon: number?}? its Crop Icons setting: 0 none, 1 or 2 more and more
---@field ElvUI_EltreumUI {skins: {shadow: {enable: boolean, length: number}?}?}?

---Eltruism, the ElvUI plugin; nil when it is not loaded.
---@class EltruismAddon
---@field ShadowColor fun(self: EltruismAddon, shadow: Frame) colours a shadow as Eltruism's own

---@type EltruismAddon?
ElvUI_EltreumUI = nil

---ElvUI's global: its engine in [1]; nil when it is not loaded.
---@type ElvUIEngine[]?
ElvUI = nil
