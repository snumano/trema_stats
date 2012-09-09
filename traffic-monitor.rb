#
# Simple layer-2 switch and switch stats sample
# This program refers to following,
# https://github.com/trema/trema/tree/develop/src/examples/traffic_monitor 
#
# Author: Shugo Numano <numano@cc.rim.or.jp>
#
# Copyright (C) 2012 Shugo Numano
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


require "fdb"

class TrafficMonitor < Controller
  periodic_timer_event :show_counter, 10


  def start
    @fdb = FDB.new
  end

  def switch_ready datapath_id
    @datapath_id = datapath_id

    send_message datapath_id, FeaturesRequest.new
    send_message datapath_id, PortStatsRequest.new
  end

  def features_reply datapath_id, message
    puts "---------" 
    p message.datapath_id
    p message.transaction_id
    p message.n_buffers
    p message.n_tables
    p message.capabilities
    p message.actions
    puts "==="
    p message.ports
  end

  def stats_reply datapath_id, message
    p message.flags
    p message.transaction_id
    p message.type
    puts message.stats
  end

  def packet_in datapath_id, message
    macsa = message.macsa
    macda = message.macda

    @fdb.learn macsa, message.in_port
    out_port = @fdb.lookup( macda )
    if out_port
      packet_out datapath_id, message, out_port
      flow_mod datapath_id, macsa, macda, out_port
    else
      flood datapath_id, message
    end
  end



  ##############################################################################
  private
  ##############################################################################


  def show_counter
    send_message @datapath_id, PortStatsRequest.new
  end


  def flow_mod datapath_id, macsa, macda, out_port
    send_flow_mod_add(
      datapath_id,
      :hard_timeout => 10,
      :match => Match.new( :dl_src => macsa, :dl_dst => macda ),
      :actions => ActionOutput.new( out_port )
    )
  end


  def packet_out datapath_id, message, out_port
    send_packet_out(
      datapath_id,
      :packet_in => message,
      :actions => ActionOutput.new( out_port )
    )
  end


  def flood datapath_id, message
    packet_out datapath_id, message, OFPP_FLOOD
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8
### indent-tabs-mode: nil
### End:
