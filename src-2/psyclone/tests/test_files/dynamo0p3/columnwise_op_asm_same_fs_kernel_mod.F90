! Modifications copyright (c) 2017, Science and Technology Facilities Council
!-------------------------------------------------------------------------------
! (c) The copyright relating to this work is owned jointly by the Crown, 
! Met Office and NERC 2014. 
! However, it has been created with the help of the GungHo Consortium, 
! whose members are identified at https://puma.nerc.ac.uk/trac/GungHo/wiki
!-------------------------------------------------------------------------------

!> @brief Kernel which assembles a locally assembled matrix (LMA) into a
!! columnwise assembled matrix (CMA). Takes a read-only field as argument too.

module columnwise_op_asm_same_fs_kernel_mod

use kernel_mod,              only : kernel_type
use argument_mod,            only : arg_type, func_type,                    &
                                    GH_OPERATOR, GH_COLUMNWISE_OPERATOR,    &
                                    GH_READ, GH_WRITE,                      &
                                    ANY_SPACE_1, ANY_SPACE_2,               &
                                    GH_COLUMN_BANDED_DOFMAP,                &
                                    CELLS 

use constants_mod,           only : r_def, i_def

implicit none

!-------------------------------------------------------------------------------
! Public types
!-------------------------------------------------------------------------------

type, public, extends(kernel_type) :: columnwise_op_asm_same_fs_kernel_type
  private
  type(arg_type) :: meta_args(3) = (/                                        &
       arg_type(GH_OPERATOR,            GH_READ,  ANY_SPACE_1, ANY_SPACE_2), &
       arg_type(GH_FIELD,               GH_READ,  ANY_SPACE_1),              &
       arg_type(GH_COLUMNWISE_OPERATOR, GH_WRITE, ANY_SPACE_2, ANY_SPACE_2)  &
       /)
  integer :: iterates_over = CELLS
contains
  procedure, nopass :: columnwise_op_asm_same_fs_kernel_code
end type

!-------------------------------------------------------------------------------
! Constructors
!-------------------------------------------------------------------------------

! overload the default structure constructor for function space
interface columnwise_op_asm_kernel_type
   module procedure columnwise_constructor
end interface

!-------------------------------------------------------------------------------
! Contained functions/subroutines
!-------------------------------------------------------------------------------
public columnwise_op_asm_same_fs_kernel_code
contains
  
  type(columnwise_op_asm_kernel_type) function columnwise_constructor() result(self)
    implicit none
    return
  end function columnwise_constructor

  !> @brief The subroutine which is called directly from the PSY layer and
  !> assembles the LMA into a CMA
  !> @detail Given an LMA representation of the operator mapping between two
  !> horizontally discontinuous spaces, assemble the columnwise matrix
  !> representation of the operator.
  !>
  !> @param [in] cell the horizontal cell index
  !> @param [in] nlayers number of vertical layers
  !> @param [in] ncell_3d total number of cells
  !> @param [in] ncell_2d number of cells in 2d grid
  !> @param [in] local_stencil locally assembled matrix
  !> @param [out] columnwise_matrix banded matrix to assemble into
  !> @param [in] nrow number of rows in the banded matrix
  !> @param [in] bandwidth bandwidth of the banded matrix
  !> @param [in] alpha banded matrix parameter \f$\alpha\f$
  !> @param [in] beta banded matrix parameter \f$\beta\f$
  !> @param [in] gamma_m banded matrix parameter \f$\gamma_-\f$
  !> @param [in] gamma_p banded matrix parameter \f$\gamma_+\f$
  !> @param [in] ndf_lma_to number of dofs per cell for the LMA to-space
  !> @param [in] undf No. of unique dofs  for the F-S that the field is on
  !> @param [in] dofmap_field Dofmap for the F-S that the field is on
  !> @param [in] column_banded_dofmap_to list of offsets for to/from-space
  subroutine columnwise_op_asm_same_fs_kernel_code(cell,              &
                                            nlayers,           &
                                            ncell_2d,          &
                                            field,             &
                                            ncell_3d,          &
                                            local_stencil,     &
                                            columnwise_matrix, &
                                            nrow,              &
                                            bandwidth,         &
                                            alpha,             &
                                            beta,              &
                                            gamma_m,           &
                                            gamma_p,           &
                                            ndf_lma_to,        & ! any_space_1
                                            undf,              & ! any_space_1
                                            dofmap_field,      &
                                            column_banded_dofmap_to)

    implicit none
    
    ! Arguments
    integer(kind=i_def), intent(in) :: cell,  nlayers, ncell_3d, ncell_2d
    integer(kind=i_def), intent(in) :: ndf_lma_to
    real(kind=r_def), dimension(ndf_lma_to,ndf_lma_to,ncell_3d), intent(in) :: local_stencil
    integer(kind=i_def), intent(in) :: nrow, bandwidth
    real(kind=r_def), dimension(bandwidth,nrow,nrow), intent(out) :: columnwise_matrix
    integer(kind=i_def), intent(in) :: alpha, beta, gamma_m, gamma_p
    integer(kind=i_def), dimension(ndf_lma_to,nlayers), intent(in) :: column_banded_dofmap_to

    write (*,*) "Hello CMA World"

  end subroutine columnwise_op_asm_same_fs_kernel_code

end module columnwise_op_asm_same_fs_kernel_mod
