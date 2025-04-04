// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IBEP20.sol";
import "./utils/SafeBEP20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./MasterRANCEWallet.sol";

// import "hardhat/console.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy PancakeSwap to CakeSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PancakeSwap LP tokens.
    // CakeSwap must mint EXACTLY the same amount of CakeSwap LP tokens or
    // else something bad will happen. Traditional PancakeSwap does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}

// MasterRANCE is the master of MUSD. He can distribute MUSD and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once MUSD is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterMUSD is Initializable, PausableUpgradeable, UUPSUpgradeable, OwnableUpgradeable{
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of MUSDs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMUSDPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMUSDPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. MUSDs to distribute per block.
        uint256 lastRewardBlock; // Last block number that MUSDs distribution occurs.
        uint256 accMUSDPerShare; // Accumulated MUSDs per share, times 1e12. See below.
    }

    // The MUSD TOKEN!
    IBEP20 public MUSD;
    // MUSD tokens distributed per block.
    uint256 public MUSDPerBlock;
    // Bonus muliplier for early stakers.
    uint256 public BONUS_MULTIPLIER;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;
    //contract holding MUSD tokens
    MasterRANCEWallet public wallet;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when MUSD mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    function initialize(
        IBEP20 _MUSD,
        uint256 _MUSDPerBlock,
        uint256 _startBlock,
        MasterRANCEWallet _wallet
    ) external initializer {
        __Ownable_init();
        MUSD = _MUSD;
        MUSDPerBlock = _MUSDPerBlock;
        startBlock = _startBlock;
        wallet = _wallet;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _MUSD,
                allocPoint: 200,
                lastRewardBlock: startBlock,
                accMUSDPerShare: 0
            })
        );

        BONUS_MULTIPLIER = 1000000;
        totalAllocPoint = 200;
    }
    
    // Authourizes upgrade to be done by the proxy. Theis contract uses a UUPS upgrade model
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner{}

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accMUSDPerShare: 0
            })
        );
    }

    // Update the given pool's MUSD allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(
                _allocPoint
            );
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending MUSDs on frontend.
    function pendingMUSD(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMUSDPerShare = pool.accMUSDPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 MUSDReward = multiplier
            .mul(MUSDPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
            uint256 MUSDBal = MUSD.balanceOf(address(wallet));
            if (MUSDReward >= MUSDBal) {
                MUSDReward = MUSDBal;
            }
            accMUSDPerShare = accMUSDPerShare.add(
                MUSDReward.mul(1e30).div(lpSupply)
            );
        }
        return user.amount.mul(accMUSDPerShare).div(1e30).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 MUSDReward = multiplier
            .mul(MUSDPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        uint256 MUSDBal = MUSD.balanceOf(address(wallet));
        if (MUSDReward >= MUSDBal) {
            MUSDReward = MUSDBal;
        }

        pool.accMUSDPerShare = pool.accMUSDPerShare.add(
            MUSDReward.mul(1e30).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterMUSD for MUSD allocation.
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
            .amount
            .mul(pool.accMUSDPerShare)
            .div(1e30)
            .sub(user.rewardDebt);
            if (pending > 0) {
                safeMUSDTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 balBefore = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(
                pool.lpToken.balanceOf(address(this)).sub(balBefore)
            );
        }
        user.rewardDebt = user.amount.mul(pool.accMUSDPerShare).div(1e30);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterMUSD.
    function withdraw(uint256 _pid, uint256 _amount) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accMUSDPerShare).div(1e30).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeMUSDTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMUSDPerShare).div(1e30);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    // helps users compound their MUSD rewards in pool 0 in a single ttansaction
    function compound() public whenNotPaused{
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accMUSDPerShare)
                .div(1e30)
                .sub(user.rewardDebt);
 
            uint256 balBefore = pool.lpToken.balanceOf(address(this));
            
            if (pending > 0) {
                safeMUSDTransfer(address(this), pending);
            }
            
            user.amount = user.amount.add(
                pool.lpToken.balanceOf(address(this)).sub(balBefore)
            );
            
            user.rewardDebt = user.amount.mul(pool.accMUSDPerShare).div(1e30);
            emit Withdraw(msg.sender, 0, pending);
            emit Deposit(msg.sender, 0, pending);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public whenPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe MUSD transfer function, just in case if rounding error causes pool to not have enough MUSDs.
    function safeMUSDTransfer(address _to, uint256 _amount) internal {
        wallet.safeTokenTransfer(_to, _amount, MUSD);
    }

    //pause deposits and withdrawals and allow only emergency withdrawals(forfeit funds)
    function pause() external onlyOwner{
        _pause();
    }

    function unpause() external onlyOwner{
        _unpause();
    }
}
