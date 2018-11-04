# Apple Music Card Transition Recreated
Apple Music now playing card transition recreated using auto-layout constraints animation.

![Demo CountPages alpha](https://thumbs.gfycat.com/LegitimateLoathsomeKoalabear-size_restricted.gif)

## Highlights
Fade in/fade out controls on pan.

![Demo CountPages alpha](https://thumbs.gfycat.com/PleasingCircularAyeaye-size_restricted.gif)

```Swift
let translationPercent = (-yTrans / nowPlayingCardView.frame.height)
collapsedControlsContainer.alpha = 1 - translationPercent * 3
expandedControlsContainer.alpha = translationPercent * 1
```

Fast present/dismiss

![Demo CountPages alpha](https://thumbs.gfycat.com/FluffyPrestigiousHedgehog-size_restricted.gif)
