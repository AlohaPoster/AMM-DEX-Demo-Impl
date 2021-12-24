# AMM-DEX-Demo-Impl
- An demo implentation of Auto Market Maker(CFMM : NumToken0 * NumToken1 == K) of DEX (DeFi)
- Solidity v0.5.x
- Sufficient Annotation in code.

![image](https://user-images.githubusercontent.com/44779211/147308309-a5ddafa9-e482-4d4a-ba2e-74a3f46ea142.png)

- 我们开发了一个DemoDEX交易所，在以CFMM为基础实现任意ERC20资产对交易的DEX的基础上，我们额外为其添加了类似CEX中的订单薄机制，使得用户可以便利地以理想价格挂单，并在流动性池价格合适时自动触发交易。实质上，这个订单薄的核心功能为“检测DEX价格并按约定自动触发交易”，其经过简单扩展即可转变为DEX聚合器或DEX自动套利脚本。
- Architecture
![image](https://user-images.githubusercontent.com/44779211/147308325-b22e4912-b760-4d7a-94b1-a4efc0e1f7e5.png)

![image](https://user-images.githubusercontent.com/44779211/147308335-c15252a9-6965-41ac-bde7-5dbeda1d4cb2.png)

- Details :
  - Factory：ERC20资产对交易合约（Pair）的生产者、记录者和索引列表，并仅通过ERC20资产地址确保Pair合约的唯一性；
  - Pair: 两种ERC20资产的流动性池，为LP（流动性提供者）提供流动性相关接口；本身亦为ERC20资产，即流动性代币（LPToken）；为用户和订单薄提供资产交换相关操作接口
  - Order Book: 订单簿为ERC20提供自动交易机制，交易方可以将需要交易的ERC20资产与可接受的最低交易价格以订单的形式挂载在自动运行的订单簿上；订单簿会在流动性池满足交易价格时自动进行交易，其优先级按照订单价格从低到高排序；用户可以为订单设置时限，也可以在交易执行前随时撤销订单；
  - DemoDEXToken: 用来测试DEX功能的ERC20代币，无限增发，任何地址可以无限领取；
