defmodule SkyscraperWeb.LayoutView do
  use SkyscraperWeb, :view

  def skyscraper_active?(building), do: SkyscraperOtp.active?(building.name)
end
