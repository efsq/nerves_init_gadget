defmodule Nerves.InitGadget do
  @moduledoc """
  `nerves_init_gadget` adds a basic level of setup for Nerves devices with USB gadget mode
  interfaces like the Raspberry Pi Zero. Here are some features:

  * Automatically sets up link-local networking on the USB interface. No DHCP or
    static IP setup is needed on the host laptop
  * Sets up mDNS to respond to lookups for `nerves.local`
  * Pulls in the `nerves_runtime` initialization for things like mounting and
    fixing the application filesystem
  * Starts `nerves_firmware_ssh` so that firmware push updates work
  * If used with [bootloader](https://github.com/nerves-project/bootloader),
    crashes in your application's initialization won't break firmware updates

  While you'll probably want to create your own device initialization project at
  some point, this project serves as a great starting point, especially if you're
  new to Nerves.

  All configuration is handled at compile-time, so there's not an API. See the
  `README.md` for installation and use instructions.
  """

  @ether_broadcast <<0xff, 0xff, 0xff, 0xff, 0xff, 0xff>>
  @eth_p_arp 0x0806
  @eth_p_ip 0x0800

  @arpop_request 1
  @arpop_reply 2

  def send_arp(ip) do
    dev = 'usb0'
    {:ok, pl} = :inet.ifget(dev, [:hwaddr, :addr])
    mac = :erlang.list_to_binary(Keyword.get(pl, :hwaddr))

    send_arp(dev, mac, ip)
  end
  def send_arp(dev, mac, ip) do
    {:ok, socket} = :packet.socket(@eth_p_ip)
    if_index = :packet.ifindex(socket, dev)

    :ok = :packet.send(socket, if_index, make_arp(@arpop_request, mac, {0, 0, 0, 0}, <<0,0,0,0,0,0>>, ip))
  end

  def send_grat_arp(ip) do
    #[dev] = :packet.default_interface()
    dev = 'usb0'
    {:ok, pl} = :inet.ifget(dev, [:hwaddr, :addr])
    mac = :erlang.list_to_binary(Keyword.get(pl, :hwaddr))
    #ip = :erlang.list_to_binary(Keyword.get(pl, :addr))
    send_grat_arp(dev, mac, ip)
  end
  def send_grat_arp(dev, mac, ip) do
    {:ok, socket} = :packet.socket(@eth_p_ip)
    if_index = :packet.ifindex(socket, dev)

    :ok = :packet.send(socket, if_index, make_arp(@arpop_request, mac, ip, mac, ip))
  end

  defp make_arp(type, sha, {sa1, sa2, sa3, sa4}, tha, {ta1, ta2, ta3, ta4}) do
    ether = << @ether_broadcast::binary,
            sha::binary-size(6),
            @eth_p_arp::integer-size(16) >>

    arp = <<
        1::integer-size(16),  # hardware type
        @eth_p_ip::integer-size(16), # protocol type
        6::integer-size(8),   # hardware length
        4::integer-size(8),   # protocol length
        type::integer-size(16), #operation
        sha::binary-size(6), # source hardware address
        sa1::size(8),
        sa2::size(8),
        sa3::size(8),
        sa4::size(8),
        tha::binary-size(6), # target hardware address
        ta1::size(8),
        ta2::size(8),
        ta3::size(8),
        ta4::size(8),
        0::size(128)
      >>

    ether <> arp
  end
end
