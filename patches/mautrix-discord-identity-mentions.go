// Patched into mautrix-discord as identity_mentions.go (package main).
package main

import (
	"github.com/bwmarrin/discordgo"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/id"

	"go.mau.fi/mautrix-discord/pkg/bridgeidentity"
)

func (portal *Portal) applyIdentityReplyMentions(
	content *event.MessageEventContent,
	allowed *discordgo.MessageAllowedMentions,
	replyToUser id.UserID,
) {
	if allowed == nil {
		return
	}

	if replyToUser != "" {
		if discordID := bridgeidentity.DiscordIDForMXID(replyToUser); discordID != "" {
			allowed.Users = appendIfNotContains(allowed.Users, discordID)
			allowed.RepliedUser = false
		}
	}

	if content.Mentions == nil {
		return
	}
	filtered := content.Mentions.UserIDs[:0]
	for _, userID := range content.Mentions.UserIDs {
		if bridgeidentity.IsDiscordBridgeBot(userID) || bridgeidentity.IsSlackBridgeBot(userID) {
			if discordID := bridgeidentity.DiscordIDForMXID(replyToUser); discordID != "" {
				allowed.Users = appendIfNotContains(allowed.Users, discordID)
				continue
			}
		}
		if discordID := bridgeidentity.DiscordIDForMXID(userID); discordID != "" {
			allowed.Users = appendIfNotContains(allowed.Users, discordID)
			filtered = append(filtered, userID)
			continue
		}
		filtered = append(filtered, userID)
	}
	content.Mentions.UserIDs = filtered
}
