# Maintainers' Rubric — Video
#
# Purpose
# - Represents an instructional video linked to a technique.
# - Includes metadata for filtering (country/year) and validation against future dates.
#
# Associations
# - belongs_to :technique
#
# Validations
# - url: presence + uniqueness.
# - country: presence.
# - year: presence + integer > 1900 and not in the future (custom validation).
#
# Notes
# - Year future check ensures data integrity for content timelines.

class Video < ApplicationRecord
  # Associations
  # A video belongs to a single technique.
  belongs_to :technique

  # Validations
  # - url: presence + uniqueness. We normalize URLs and restrict to YouTube
  #   URLs for now (only YouTube links are accepted as video sources).
  # - country: presence.
  # - year: presence + integer > 1900. We also explicitly check not-in-future
  #   and surface a clear error message.
  validates :url, presence: true, uniqueness: true
  validates :country, presence: true
  validates :year,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 1900
            }

  # Normalize URL inputs and ensure we only accept YouTube links.
  before_validation :normalize_url
  validate :url_must_be_youtube
  validate :year_is_not_in_the_future

  private

  def year_is_not_in_the_future
    if year.present? && year > Date.today.year
      errors.add(
        :year,
        "can't be in the future (must be <= #{Date.today.year})"
      )
    end
  end

  # Normalize the stored URL to a canonical YouTube watch URL when possible.
  # - Strips surrounding whitespace
  # - Converts short youtu.be links to full youtube.com/watch?v= form
  # - Forces https and a minimal canonical form: https://www.youtube.com/watch?v=VIDEO_ID
  def normalize_url
    return if url.blank?

    u = url.to_s.strip
    begin
      uri = URI.parse(u)
    rescue URI::InvalidURIError
      # leave as-is; validation will catch malformed URLs
      self.url = u
      return
    end

    host = uri.host.to_s.downcase
    # Extract a video id where possible
    vid = nil
    if host.include?("youtu.be")
      vid = uri.path.to_s.split("/").last
    elsif host.include?("youtube.com")
      params = Rack::Utils.parse_nested_query(uri.query.to_s)
      vid = params["v"]
      if vid.blank?
        # Support embedded forms like /embed/VIDEO_ID or /v/VIDEO_ID
        vid = Regexp.last_match(1) if uri.path =~ %r{/(?:embed|v)/([^/?]+)}
      end
    end

    if vid.present?
      self.url = "https://www.youtube.com/watch?v=#{vid}"
    else
      # Fall back to a normalized scheme/host/path reconstruction
      scheme = uri.scheme.presence || "https"
      normalized_host = host
      normalized_path = uri.path.to_s
      normalized_path = normalized_path.chomp("/") unless normalized_path == "/"
      self.url =
        "#{scheme}://#{normalized_host}#{normalized_path}#{uri.query.present? ? "?#{uri.query}" : ""}"
    end
  end

  # Ensure the URL is a valid YouTube URL and contains a plausible video id.
  def url_must_be_youtube
    return if url.blank?

    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      errors.add(:url, "is not a valid URL")
      return
    end

    unless %w[http https].include?(uri.scheme)
      errors.add(:url, "must use http or https")
      return
    end

    host = uri.host.to_s.downcase
    unless host.include?("youtube.com") || host.include?("youtu.be")
      errors.add(:url, "must be a YouTube URL")
      return
    end

    # Check for presence of a video id
    params = Rack::Utils.parse_nested_query(uri.query.to_s)
    vid = params["v"] || uri.path.to_s.split("/").last
    if vid.blank? || vid.length < 5
      errors.add(:url, "does not contain a valid YouTube video id")
    end
  end
end
