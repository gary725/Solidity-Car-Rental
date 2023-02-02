# Solidity-Car-Rental

23/02/02更新

1.修改变量名

Car

carbrand -> carBrand

species -> carType

rent_per_hour -> rentPerHour

Customer

添加bool existence

2.增加addCar和autoAddCar，可以向Cars列表（库存）增加车辆实例，autoAddCar可以向库存中自动添加预设车辆用来快速测试

3.viewCar可以查看车辆租赁状态，租费和押金直接显示为ETH个数

4.buyTokens中的rentalBalance(token库存)仍然无法更新，原因是token.balanceOf(address(this))的用法不清楚，暂时无法改变这一项的值，无法增加token余额，会显示"Not enough tokens in the reserve"，需要协作解决

5.startRental

1)用Car的customer属性是否为空值来判断用户输入的carID车辆是否存在，如果不是空值，说明车辆在库存中或正在租赁中，如果空值说明没有对应车辆实例

2)删除判断customer是否isRenting，因此现在用户可租用多辆车

3)要求开始租赁时用户ETH余额大于车型押金

4)当用户第一次开始租赁时，将existence属性设为true

5)只有customer能访问租赁功能

6.stopRental

1)要求用户在租赁状态中才能访问停止租赁功能

2)租金现在取决于车型，比如1001车租金费率为1 ETH每小时

3)结算功能已经写好只需略微修改

4)return中可以显示租赁时间和支付价格

5)只有customer能访问停止租赁功能

7.checkCustomerStatus

只有customer能访问，可以查看当前用户租赁状态、租用车辆、开始时间，用于测试
