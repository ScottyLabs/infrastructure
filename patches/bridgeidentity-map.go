// Shared source for mautrix-slack and mautrix-discord patches (copied to pkg/bridgeidentity/map.go).
package bridgeidentity

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"
	"sync"

	"maunium.net/go/mautrix/id"
)

type link struct {
	DiscordID   string `json:"discord_id"`
	SlackUserID string `json:"slack_user_id"`
}

type file struct {
	SlackTeamID string `json:"slack_team_id"`
	Links       []link `json:"links"`
}

// Map holds Keycloak-linked Discord ↔ Slack user IDs for cross-platform mentions.
type Map struct {
	slackTeamID    string
	discordToSlack map[string]string
	slackToDiscord map[string]string
}

var (
	loadOnce          sync.Once
	globalMap         *Map
	discordGhostRegex = regexp.MustCompile(`^@discord_([0-9]+):`)
)

func DefaultPath() string {
	if p := os.Getenv("BRIDGE_IDENTITY_MAP_PATH"); p != "" {
		return p
	}
	return "/etc/mautrix-bridge/identity-map.json"
}

// Get returns the loaded identity map (empty if missing or invalid).
func Get() *Map {
	loadOnce.Do(func() {
		globalMap = load(DefaultPath())
	})
	return globalMap
}

func load(path string) *Map {
	m := &Map{
		discordToSlack: make(map[string]string),
		slackToDiscord: make(map[string]string),
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return m
	}
	var f file
	if err := json.Unmarshal(raw, &f); err != nil {
		return m
	}
	m.slackTeamID = strings.ToUpper(f.SlackTeamID)
	for _, l := range f.Links {
		if l.DiscordID == "" || l.SlackUserID == "" {
			continue
		}
		m.discordToSlack[l.DiscordID] = strings.ToUpper(l.SlackUserID)
		m.slackToDiscord[strings.ToUpper(l.SlackUserID)] = l.DiscordID
	}
	return m
}

func (m *Map) SlackUserIDForDiscord(discordID string) string {
	if m == nil {
		return ""
	}
	return m.discordToSlack[discordID]
}

func (m *Map) DiscordIDForSlack(slackUserID string) string {
	if m == nil {
		return ""
	}
	return m.slackToDiscord[strings.ToUpper(slackUserID)]
}

func (m *Map) HasDiscord(discordID string) bool {
	return m.SlackUserIDForDiscord(discordID) != ""
}

// ParseDiscordGhostMXID extracts a Discord snowflake from a discord bridge puppet MXID.
func ParseDiscordGhostMXID(mxid id.UserID) string {
	match := discordGhostRegex.FindStringSubmatch(string(mxid))
	if len(match) == 2 {
		return match[1]
	}
	return ""
}

// ParseSlackGhostUserID extracts a Slack user ID from a slack bridge puppet MXID.
func ParseSlackGhostUserID(mxid id.UserID) string {
	localpart, _, err := mxid.ParseAndDecode()
	if err != nil {
		return ""
	}
	candidates := []string{localpart}
	if strings.HasPrefix(localpart, "slack_") {
		candidates = append(candidates, strings.TrimPrefix(localpart, "slack_"))
	}
	for _, part := range candidates {
		decoded, err := id.DecodeUserLocalpart(part)
		if err != nil {
			continue
		}
		parts := strings.Split(string(decoded), "-")
		if len(parts) != 2 {
			continue
		}
		return strings.ToUpper(parts[1])
	}
	return ""
}
